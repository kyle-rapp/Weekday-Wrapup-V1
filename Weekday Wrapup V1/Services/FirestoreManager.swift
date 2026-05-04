import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

/// FILE: Services/FirestoreManager.swift
/// Central Firestore access: real-time feed, comments subcollection, likes, reactions, following.
@MainActor
final class FirestoreManager: ObservableObject {
    static let shared = FirestoreManager()

    @Published private(set) var posts: [FeedPost] = []
    @Published private(set) var detailComments: [Comment] = []
    @Published private(set) var followingIds: Set<String> = []
    /// Group ids the current user belongs to (for `PostVisibility.groups` feed filtering).
    @Published private(set) var joinedGroupIds: Set<String> = []
    @Published private(set) var myGroups: [SocialGroup] = []
    /// User-visible Firestore / auth errors (optional alert in views).
    @Published var errorMessage: String?
    /// Latest context-aware suggestion from emotional pattern detection.
    @Published var activeNudge: String?

    /// Lazily created so Xcode Previews never touch Firestore unless a Firebase-backed method runs.
    private lazy var db: Firestore = Firestore.firestore()
    /// Latest documents from Firestore before visibility filtering.
    private var allPostsRaw: [FeedPost] = []
    private var postsListener: ListenerRegistration?
    private var commentsListener: ListenerRegistration?
    private var followingListener: ListenerRegistration?
    private var groupsListener: ListenerRegistration?
    /// Personalized learning cache for the signed-in viewer.
    private var profileCacheUserId: String?
    private var cachedHelpfulProfile: [String: Int] = [:]
    private var cachedSimilarUserIds: Set<String> = []

    private init() {}

    private static var isXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    private var isUITestMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest-mode")
    }

    func clearErrorMessage() {
        errorMessage = nil
    }

    // MARK: - Auth guard (writes)

    /// Ensures Firebase Auth has a signed-in user; optionally verifies `uid` matches the signed-in account.
    private func requireAuthUser(matchingExpectedUid expectedUid: String) throws -> FirebaseAuth.User {
        if Self.isXcodePreview {
            print("⚠️ Firestore write skipped (Xcode Preview)")
            throw NSError(
                domain: "FirestoreManager",
                code: -100,
                userInfo: [NSLocalizedDescriptionKey: "Not available in Xcode Preview"]
            )
        }
        guard let user = Auth.auth().currentUser else {
            print("❌ No authenticated user")
            errorMessage = "You must be signed in."
            throw NSError(
                domain: "FirestoreManager",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "No authenticated user"]
            )
        }
        guard user.uid == expectedUid else {
            print("❌ Auth user mismatch (expected \(expectedUid), got \(user.uid))")
            errorMessage = "Session error. Please sign in again."
            throw NSError(
                domain: "FirestoreManager",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Signed-in user does not match this action"]
            )
        }
        return user
    }

    private func runWrite<T>(successLog: String, operation: () async throws -> T) async throws -> T {
        do {
            let value = try await operation()
            errorMessage = nil
            AppLogger.log("[FIRESTORE] Write success: \(successLog)")
            return value
        } catch {
            let msg = error.localizedDescription
            AppLogger.error("[FIRESTORE] Write failed: \(msg)")
            errorMessage = msg
            throw error
        }
    }

    private func reportListenerError(_ context: String, error: Error) {
        let msg = error.localizedDescription
        AppLogger.error("\(context): \(msg)")
        errorMessage = msg
    }

    // MARK: - Session teardown

    func teardownForLogout() {
        stopPostsListener()
        stopCommentsListener()
        stopFollowingListener()
        stopGroupsListener()
        followingIds = []
        joinedGroupIds = []
        myGroups = []
        profileCacheUserId = nil
        cachedHelpfulProfile = [:]
        cachedSimilarUserIds = []
        activeNudge = nil
        errorMessage = nil
    }

    // MARK: - Posts listener

    func startPostsListener() {
        if isUITestMode {
            if posts.isEmpty {
                applyPreviewPosts(SeedDataManager.previewSeedPosts())
            }
            return
        }
        stopPostsListener()
        postsListener = db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 60)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    Task { @MainActor in
                        self.reportListenerError("Posts listener", error: error)
                    }
                    return
                }
                guard let documents = snapshot?.documents else { return }
                let mapped = documents.compactMap { FeedPost(document: $0) }
                Task { @MainActor in
                    self.allPostsRaw = mapped
                    self.applyPostVisibilityFilter()
                }
            }
    }

    private func applyPostVisibilityFilter() {
        let uid = Auth.auth().currentUser?.uid
        refreshPersonalLearningCacheIfNeeded(viewerId: uid)
        if let uid {
            cachedSimilarUserIds = similarUserIds(for: uid, in: allPostsRaw)
        } else {
            cachedSimilarUserIds = []
        }
        let visible = allPostsRaw.filter { Self.postMeetsVisibility($0, viewerId: uid, joinedGroupIds: joinedGroupIds) }
        posts = rankPostsForFeed(visible, viewerId: uid)
    }

    /// Emotion-aware ranked feed with overload caps.
    private func rankPostsForFeed(_ items: [FeedPost], viewerId: String?) -> [FeedPost] {
        guard let viewerId else {
            return items.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        }
        let context = FeedScoreContext(
            currentUserId: viewerId,
            followingIds: followingIds,
            now: Date()
        )
        let ranked = items
            .map { ($0, scorePost($0, context: context)) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return (lhs.0.createdAt ?? .distantPast) > (rhs.0.createdAt ?? .distantPast)
            }
            .map(\.0)
        return applyFeedOverloadCaps(ranked)
    }

    func scorePost(_ post: FeedPost, context: FeedScoreContext) -> Double {
        var score = 0.0

        if context.followingIds.contains(post.authorId) {
            score += 5
        }

        if let intensity = post.intensity {
            if intensity >= 8 {
                score += 6
            } else if intensity >= 6 {
                score += 3
            }
        }

        let toughEmotions = ["sad", "anxious", "overwhelmed", "lonely"]
        if toughEmotions.contains(where: { post.primaryEmotion.lowercased().contains($0) }) {
            score += 4
        }

        score += Double(post.likeCount) * 0.5
        score += Double(post.commentCount) * 1.2

        let createdAt = post.createdAt ?? .distantPast
        let hours = context.now.timeIntervalSince(createdAt) / 3600
        score -= hours * 0.8

        if post.tags.contains(where: { $0.caseInsensitiveCompare("milestone") == .orderedSame }) {
            score += 8
        }

        let helpfulBoostTags = ["exercise", "mindfulness", "social", "rest"]
        if post.helpfulTags.contains(where: { helpfulBoostTags.contains($0.lowercased()) }) {
            score += 5
        }

        for tag in post.helpfulTags {
            if let count = cachedHelpfulProfile[tag.lowercased()] {
                score += Double(count) * 1.5
            }
        }

        if cachedSimilarUserIds.contains(post.authorId) {
            score += 6
        }

        return score
    }

    private func refreshPersonalLearningCacheIfNeeded(viewerId: String?) {
        guard let viewerId else {
            profileCacheUserId = nil
            cachedHelpfulProfile = [:]
            return
        }
        guard profileCacheUserId != viewerId else { return }
        profileCacheUserId = viewerId
        Task { @MainActor in
            let profile = await fetchUserHelpfulProfile(userId: viewerId)
            cachedHelpfulProfile = profile
            let visible = allPostsRaw.filter { Self.postMeetsVisibility($0, viewerId: viewerId, joinedGroupIds: joinedGroupIds) }
            posts = rankPostsForFeed(visible, viewerId: viewerId)
        }
    }

    private func similarUserIds(for viewerId: String, in feedPosts: [FeedPost]) -> Set<String> {
        let grouped = Dictionary(grouping: feedPosts, by: \.authorId)
        guard let mine = grouped[viewerId], !mine.isEmpty else { return [] }

        let mySignature = buildUserSignature(entries: mine.map { CheckInData.fromPostedWrapup($0) })
        guard mySignature.sampleSize >= 2 else { return [] }

        let matches = grouped.compactMap { (authorId, posts) -> (String, Double)? in
            guard authorId != viewerId else { return nil }
            let signature = buildUserSignature(entries: posts.map { CheckInData.fromPostedWrapup($0) })
            guard signature.sampleSize >= 2 else { return nil }
            let score = similarityScore(mySignature, signature)
            guard score >= 0.35 else { return nil }
            return (authorId, score)
        }

        return Set(
            matches
                .sorted { $0.1 > $1.1 }
                .prefix(20)
                .map(\.0)
        )
    }

    func similarityScore(_ userA: UserEmotionalSignature, _ userB: UserEmotionalSignature) -> Double {
        let tagsA = Set(userA.topHelpfulTags.map { $0.lowercased() })
        let tagsB = Set(userB.topHelpfulTags.map { $0.lowercased() })
        let emotionsA = Set(userA.topEmotions.map { $0.lowercased() })
        let emotionsB = Set(userB.topEmotions.map { $0.lowercased() })

        let tagUnion = tagsA.union(tagsB)
        let emotionUnion = emotionsA.union(emotionsB)
        let tagScore = tagUnion.isEmpty ? 0 : Double(tagsA.intersection(tagsB).count) / Double(tagUnion.count)
        let emotionScore = emotionUnion.isEmpty ? 0 : Double(emotionsA.intersection(emotionsB).count) / Double(emotionUnion.count)

        let intensityDelta = abs(userA.averageIntensity - userB.averageIntensity)
        let intensityScore = max(0, 1 - (intensityDelta / 10))
        return (tagScore * 0.5) + (emotionScore * 0.35) + (intensityScore * 0.15)
    }

    private func applyFeedOverloadCaps(_ ranked: [FeedPost]) -> [FeedPost] {
        var output: [FeedPost] = []
        var queue = ranked
        var consecutiveHeavy = 0

        while !queue.isEmpty {
            let next = queue.removeFirst()
            let isHeavy = isHeavyEmotionalPost(next)
            if isHeavy && consecutiveHeavy >= 2 {
                if let idx = queue.firstIndex(where: { !isHeavyEmotionalPost($0) }) {
                    let lighter = queue.remove(at: idx)
                    output.append(lighter)
                    consecutiveHeavy = 0
                    queue.insert(next, at: 0)
                    continue
                }
            }
            output.append(next)
            consecutiveHeavy = isHeavy ? consecutiveHeavy + 1 : 0
        }
        return output
    }

    private func isHeavyEmotionalPost(_ post: FeedPost) -> Bool {
        let intensityHeavy = (post.intensity ?? 0) >= 8
        let tough = ["sad", "anxious", "overwhelmed", "lonely"]
            .contains(where: { post.primaryEmotion.lowercased().contains($0) })
        return intensityHeavy || tough
    }

    /// Feed visibility: public / friends-style posts for all; private = author only; groups = author + shared group members.
    private static func postMeetsVisibility(_ post: FeedPost, viewerId: String?, joinedGroupIds: Set<String>) -> Bool {
        guard let viewerId else { return false }
        if post.authorId == viewerId { return true }
        switch post.visibility {
        case .public:
            return true
        case .friends:
            return true
        case .private:
            return false
        case .groups:
            let ids = post.sharedGroupIds
            guard !ids.isEmpty else { return false }
            return ids.contains(where: { joinedGroupIds.contains($0) })
        }
    }

    // MARK: - Groups (`groups` collection)

    func startGroupsListener(userId: String) {
        if isUITestMode {
            myGroups = []
            joinedGroupIds = []
            return
        }
        #if DEBUG
        if Self.isXcodePreview { return }
        #endif
        stopGroupsListener()
        groupsListener = db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    Task { @MainActor in
                        self.reportListenerError("Groups listener", error: error)
                    }
                    return
                }
                guard let documents = snapshot?.documents else { return }
                    let groups: [SocialGroup] = documents.compactMap { doc in
                    let data = doc.data()
                    guard let name = data["name"] as? String,
                          let memberIds = data["memberIds"] as? [String] else { return nil }
                    let owner = (data["ownerId"] as? String) ?? (data["createdBy"] as? String) ?? ""
                    guard !owner.isEmpty else { return nil }
                    let invited = data["invitedContacts"] as? [String]
                    let allowHistory = data["allowHistoryAccessForNewMembers"] as? Bool
                    let desc = data["description"] as? String
                    let adminIds = data["adminIds"] as? [String]
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                    let memberHistoryAccess = data["memberHistoryAccess"] as? [String: Bool]
                    return SocialGroup(
                        id: doc.documentID,
                        name: name,
                        memberIds: memberIds,
                        createdBy: owner,
                        adminIds: adminIds ?? [owner],
                        createdAt: createdAt,
                        invitedContacts: invited,
                        allowHistoryAccessForNewMembers: allowHistory,
                        memberHistoryAccess: memberHistoryAccess,
                        description: desc
                    )
                }
                Task { @MainActor in
                    self.myGroups = groups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    self.joinedGroupIds = Set(groups.map(\.id))
                    self.applyPostVisibilityFilter()
                }
            }
    }

    func stopGroupsListener() {
        groupsListener?.remove()
        groupsListener = nil
        joinedGroupIds = []
        myGroups = []
    }

    /// Creates a `groups` document. Writes `ownerId` and legacy `createdBy` (same uid) for compatibility.
    func createGroup(
        name: String,
        description: String? = nil,
        memberIds: [String],
        ownerId: String,
        invitedContacts: [String]? = nil,
        allowHistoryAccessForNewMembers: Bool? = nil
    ) async throws {
        _ = try requireAuthUser(matchingExpectedUid: ownerId)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "FirestoreManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Group name is required"])
        }
        var members = Set(memberIds)
        members.insert(ownerId)
        let trimmedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedInvites = (invitedContacts ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        try await runWrite(successLog: "Group created") {
            let ref = self.db.collection("groups").document()
            var payload: [String: Any] = [
                "name": trimmed,
                "memberIds": Array(members),
                "ownerId": ownerId,
                "createdBy": ownerId,
                "adminIds": [ownerId],
                "createdAt": FieldValue.serverTimestamp()
            ]
            if !trimmedDescription.isEmpty {
                payload["description"] = trimmedDescription
            }
            if !trimmedInvites.isEmpty {
                payload["invitedContacts"] = trimmedInvites
            }
            if let allowHistoryAccessForNewMembers {
                payload["allowHistoryAccessForNewMembers"] = allowHistoryAccessForNewMembers
            }
            try await ref.setData(payload)
        }
    }

    func updateGroup(
        groupId: String,
        memberIds: [String],
        invitedContacts: [String],
        allowHistoryAccessForNewMembers: Bool,
        actingUserId: String
    ) async throws {
        _ = try requireAuthUser(matchingExpectedUid: actingUserId)
        let ref = db.collection("groups").document(groupId)
        let snap = try await ref.getDocument()
        guard let data = snap.data() else {
            throw NSError(domain: "FirestoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
        }
        let owner = (data["ownerId"] as? String) ?? (data["createdBy"] as? String) ?? ""
        guard owner == actingUserId else {
            throw NSError(domain: "FirestoreManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the group owner can change settings"])
        }
        var members = Set(memberIds)
        members.insert(owner)
        let trimmedInvites = invitedContacts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let rawAdmins = data["adminIds"] as? [String]
        let resolvedAdmins = (rawAdmins?.isEmpty == false) ? rawAdmins! : [owner]
        let update: [String: Any] = [
            "memberIds": Array(members),
            "invitedContacts": trimmedInvites,
            "allowHistoryAccessForNewMembers": allowHistoryAccessForNewMembers,
            "adminIds": resolvedAdmins
        ]
        try await runWrite(successLog: "Group updated") {
            try await ref.updateData(update)
        }
    }

    /// Adds a member by user id (owner or admin). Optionally records whether they may see past group content.
    func addGroupMember(groupId: String, memberUserId: String, actingUserId: String, canSeePastMessages: Bool? = nil) async throws {
        _ = try requireAuthUser(matchingExpectedUid: actingUserId)
        let ref = db.collection("groups").document(groupId)
        let snap = try await ref.getDocument()
        guard let data = snap.data() else {
            throw NSError(domain: "FirestoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
        }
        let owner = (data["ownerId"] as? String) ?? (data["createdBy"] as? String) ?? ""
        let rawAdmins = data["adminIds"] as? [String]
        let admins = (rawAdmins?.isEmpty == false) ? rawAdmins! : [owner]
        guard owner == actingUserId || admins.contains(actingUserId) else {
            throw NSError(domain: "FirestoreManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only an admin can add members"])
        }
        var members = Set(data["memberIds"] as? [String] ?? [])
        members.insert(owner)
        members.insert(memberUserId)
        var update: [String: Any] = ["memberIds": Array(members)]
        if let canSeePastMessages {
            var historyMap = (data["memberHistoryAccess"] as? [String: Bool]) ?? [:]
            historyMap[memberUserId] = canSeePastMessages
            update["memberHistoryAccess"] = historyMap
        }
        try await runWrite(successLog: "Member added") {
            try await ref.updateData(update)
        }
    }

    /// Removes a member (owner or admin). Cannot remove owner.
    func removeGroupMember(groupId: String, memberUserId: String, actingUserId: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: actingUserId)
        let ref = db.collection("groups").document(groupId)
        let snap = try await ref.getDocument()
        guard let data = snap.data() else {
            throw NSError(domain: "FirestoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
        }
        let owner = (data["ownerId"] as? String) ?? (data["createdBy"] as? String) ?? ""
        let rawAdmins = data["adminIds"] as? [String]
        let admins = (rawAdmins?.isEmpty == false) ? rawAdmins! : [owner]
        guard owner == actingUserId || admins.contains(actingUserId) else {
            throw NSError(domain: "FirestoreManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only an admin can remove members"])
        }
        guard memberUserId != owner else {
            throw NSError(domain: "FirestoreManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot remove the group owner"])
        }
        var members = Set(data["memberIds"] as? [String] ?? [])
        members.remove(memberUserId)
        members.insert(owner)
        try await runWrite(successLog: "Member removed") {
            try await ref.updateData(["memberIds": Array(members)])
        }
    }

    /// Best-effort: finds users whose `name` field matches exactly (case-sensitive as stored).
    func lookupUserIdsByExactDisplayName(_ name: String) async -> [String] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        #if DEBUG
        if Self.isXcodePreview { return [] }
        #endif
        do {
            let snap = try await db.collection("users").whereField("name", isEqualTo: trimmed).limit(to: 8).getDocuments()
            return snap.documents.map(\.documentID)
        } catch {
            print("⚠️ lookupUserIdsByExactDisplayName: \(error.localizedDescription)")
            return []
        }
    }

    /// Posted wrapup for navigation from history (`CheckInData.id` is the post id).
    func feedPost(byId id: String) -> FeedPost? {
        posts.first { $0.id == id }
    }

    func stopPostsListener() {
        postsListener?.remove()
        postsListener = nil
        allPostsRaw = []
        posts = []
    }

    /// Wrapups authored by `userId`, newest first, for history and insights.
    func wrapupHistoryEntries(forUserId userId: String?) -> [CheckInData] {
        guard let userId else { return [] }
        return posts
            .filter { $0.authorId == userId }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .map { CheckInData.fromPostedWrapup($0) }
    }

    #if DEBUG
    /// Seed the feed for SwiftUI Previews without starting a Firestore listener.
    func applyPreviewPosts(_ newPosts: [FeedPost]) {
        postsListener?.remove()
        postsListener = nil
        allPostsRaw = newPosts
        applyPostVisibilityFilter()
    }

    func applyPreviewComments(_ list: [Comment]) {
        commentsListener?.remove()
        commentsListener = nil
        detailComments = Comment.nestedTree(from: list)
    }

    func applyPreviewFollowing(_ ids: Set<String>) {
        followingListener?.remove()
        followingListener = nil
        followingIds = ids
    }
    #endif

    // MARK: - Comments (subcollection + real-time)

    func startCommentsListener(postId: String) {
        #if DEBUG
        if Self.isXcodePreview { return }
        #endif
        stopCommentsListener()
        commentsListener = db.collection("posts").document(postId).collection("comments")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    Task { @MainActor in
                        self.reportListenerError("Comments listener", error: error)
                    }
                    return
                }
                guard let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    let nested = await self.mergedCommentTree(postId: postId, mainDocuments: documents)
                    self.detailComments = nested
                }
            }
    }

    /// Merges top-level `comments` docs with `comments/{rootId}/replies` (new) plus legacy inline replies (`parentCommentId` on main docs).
    private func mergedCommentTree(postId: String, mainDocuments: [QueryDocumentSnapshot]) async -> [Comment] {
        var flat = mainDocuments.compactMap { Comment(document: $0) }
        let roots = flat.filter { $0.parentCommentId == nil }
        for root in roots {
            let repliesRef = db.collection("posts").document(postId).collection("comments").document(root.id).collection("replies")
            do {
                let rs = try await repliesRef.order(by: "createdAt", descending: false).getDocuments()
                for d in rs.documents {
                    if let c = Comment(replyDocument: d, threadRootId: root.id, parentCommentId: root.id) {
                        flat.append(c)
                    }
                }
            } catch {
                print("⚠️ replies subcollection: \(error.localizedDescription)")
            }
        }
        return Comment.nestedTree(from: flat)
    }

    func stopCommentsListener() {
        commentsListener?.remove()
        commentsListener = nil
        detailComments = []
    }

    /// Writes `posts/{postId}/comments/{id}` and increments `commentCount` on the post. Ignores whitespace-only text.
    func addComment(postId: String, userId: String, userName: String, text: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let err = NSError(domain: "FirestoreManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Comment cannot be empty"])
            print("❌ Comment rejected: empty after trim")
            errorMessage = err.localizedDescription
            throw err
        }
        try await runWrite(successLog: "Comment added") {
            let postRef = self.db.collection("posts").document(postId)
            let commentRef = postRef.collection("comments").document()
            let batch = self.db.batch()
            batch.setData([
                "userId": userId,
                "userName": userName,
                "text": trimmed,
                "createdAt": FieldValue.serverTimestamp(),
                "likeCount": 0,
                "likedBy": [] as [String],
                "reactions": [:] as [String: Any]
            ], forDocument: commentRef)
            batch.updateData(["commentCount": FieldValue.increment(Int64(1))], forDocument: postRef)
            try await batch.commit()
        }
    }

    /// Reply at `posts/{postId}/comments/{parentCommentId}/replies/{replyId}`; increments post `commentCount`.
    func addReplyComment(postId: String, parentCommentId: String, userId: String, userName: String, text: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let err = NSError(domain: "FirestoreManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Reply cannot be empty"])
            errorMessage = err.localizedDescription
            throw err
        }
        try await runWrite(successLog: "Reply added") {
            let postRef = self.db.collection("posts").document(postId)
            let parentRef = postRef.collection("comments").document(parentCommentId)
            let replyRef = parentRef.collection("replies").document()
            let batch = self.db.batch()
            batch.setData([
                "userId": userId,
                "userName": userName,
                "text": trimmed,
                "createdAt": FieldValue.serverTimestamp(),
                "likeCount": 0,
                "likedBy": [] as [String],
                "reactions": [:] as [String: Any]
            ], forDocument: replyRef)
            batch.updateData(["commentCount": FieldValue.increment(Int64(1))], forDocument: postRef)
            try await batch.commit()
        }
    }

    func toggleCommentLike(postId: String, comment: Comment, userId: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        try await runWrite(successLog: "Comment like updated") {
            try await self.performToggleCommentLike(postId: postId, comment: comment, userId: userId)
        }
    }

    private func commentDocumentRef(postId: String, comment: Comment) -> DocumentReference {
        let post = db.collection("posts").document(postId)
        if let root = comment.threadRootId {
            return post.collection("comments").document(root).collection("replies").document(comment.id)
        }
        return post.collection("comments").document(comment.id)
    }

    private func performToggleCommentLike(postId: String, comment: Comment, userId: String) async throws {
        let docRef = commentDocumentRef(postId: postId, comment: comment)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                do {
                    let snapshot = try transaction.getDocument(docRef)
                    guard snapshot.exists, let data = snapshot.data() else {
                        throw NSError(domain: "FirestoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Comment not found"])
                    }
                    var likedBy = data["likedBy"] as? [String] ?? []
                    var likedSet = Set(likedBy)
                    var likeCount = data["likeCount"] as? Int ?? 0
                    if likeCount == 0, let n = data["likeCount"] as? NSNumber {
                        likeCount = n.intValue
                    }
                    if likedSet.contains(userId) {
                        likedSet.remove(userId)
                        likeCount = max(0, likeCount - 1)
                    } else {
                        likedSet.insert(userId)
                        likeCount += 1
                    }
                    likedBy = Array(likedSet)
                    transaction.updateData([
                        "likedBy": likedBy,
                        "likeCount": likeCount
                    ], forDocument: docRef)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func incrementCommentReaction(postId: String, comment: Comment, emoji: String, userId: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        try await runWrite(successLog: "Comment reaction updated") {
            try await self.performIncrementCommentReaction(postId: postId, comment: comment, emoji: emoji)
        }
    }

    private func performIncrementCommentReaction(postId: String, comment: Comment, emoji: String) async throws {
        let docRef = commentDocumentRef(postId: postId, comment: comment)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                do {
                    let snapshot = try transaction.getDocument(docRef)
                    guard snapshot.exists else {
                        throw NSError(domain: "FirestoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Comment not found"])
                    }
                    let path = FieldPath(["reactions", emoji])
                    transaction.updateData([path: FieldValue.increment(Int64(1))], forDocument: docRef)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    // MARK: - Following

    private func followersCollection(userId: String) -> CollectionReference {
        db.collection("followers").document(userId).collection("userFollowers")
    }

    private func followingCollection(userId: String) -> CollectionReference {
        db.collection("following").document(userId).collection("userFollowing")
    }

    private func insightsSignatureRef(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("insights").document("signature")
    }

    private func insightsProfileRef(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("insights").document("profile")
    }

    func startFollowingListener(userId: String) {
        if isUITestMode {
            followingIds = []
            return
        }
        #if DEBUG
        if Self.isXcodePreview { return }
        #endif
        stopFollowingListener()
        followingListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    Task { @MainActor in
                        self.reportListenerError("Following listener", error: error)
                    }
                    return
                }
                guard let data = snapshot?.data() else { return }
                let raw = data["following"] as? [Any] ?? []
                let ids: [String] = raw.compactMap { $0 as? String }
                Task { @MainActor in
                    self.followingIds = Set(ids)
                }
            }
    }

    func stopFollowingListener() {
        followingListener?.remove()
        followingListener = nil
        followingIds = []
    }

    func isFollowing(_ userId: String) -> Bool {
        followingIds.contains(userId)
    }

    func fetchFollowerCount(userId: String) async -> Int {
        if Self.isXcodePreview { return 0 }
        do {
            let aggregate = try await followersCollection(userId: userId).count.getAggregation(source: .server)
            return Int(truncating: aggregate.count)
        } catch {
            AppLogger.error("fetchFollowerCount failed: \(error.localizedDescription)")
            return 0
        }
    }

    func fetchFollowingCount(userId: String) async -> Int {
        if Self.isXcodePreview { return 0 }
        do {
            let aggregate = try await followingCollection(userId: userId).count.getAggregation(source: .server)
            return Int(truncating: aggregate.count)
        } catch {
            AppLogger.error("fetchFollowingCount failed: \(error.localizedDescription)")
            return 0
        }
    }

    func fetchFollowers(userId: String, limit: Int = 100) async -> [AppUser] {
        if Self.isXcodePreview { return [] }
        do {
            let docs = try await followersCollection(userId: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            let ids = docs.documents.map(\.documentID)
            return await fetchUsersByIds(ids)
        } catch {
            AppLogger.error("fetchFollowers failed: \(error.localizedDescription)")
            return []
        }
    }

    func fetchFollowingUsers(userId: String, limit: Int = 100) async -> [AppUser] {
        if Self.isXcodePreview { return [] }
        do {
            let docs = try await followingCollection(userId: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            let ids = docs.documents.map(\.documentID)
            return await fetchUsersByIds(ids)
        } catch {
            AppLogger.error("fetchFollowingUsers failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Display name from `users/{userId}` (best-effort).
    func userDisplayName(userId: String) async -> String {
        #if DEBUG
        if Self.isXcodePreview { return "Friend" }
        #endif
        do {
            let snap = try await db.collection("users").document(userId).getDocument()
            if let name = snap.data()?["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return name
            }
        } catch {
            print("⚠️ userDisplayName: \(error.localizedDescription)")
        }
        return "User \(String(userId.prefix(8)))"
    }

    /// App-level profile summary with social counts (distinct from `UserProfile` in profile system).
    func fetchAppUserProfile(userId: String) async -> AppUser? {
        if Self.isXcodePreview { return nil }
        do {
            let snap = try await db.collection("users").document(userId).getDocument()
            guard let data = snap.data() else { return nil }
            return appUserFromDocument(id: userId, data: data)
        } catch {
            AppLogger.error("fetchAppUserProfile failed: \(error.localizedDescription)")
            return nil
        }
    }

    func fetchUserProfile(userId: String, includeSocialCounts: Bool) async -> AppUser? {
        let user = await fetchAppUserProfile(userId: userId)
        guard includeSocialCounts, var user else { return user }
        async let followers = fetchFollowerCount(userId: userId)
        async let following = fetchFollowingCount(userId: userId)
        user.followerCount = await followers
        user.followingCount = await following
        return user
    }

    func searchUsers(query: String) async -> [AppUser] {
        if Self.isXcodePreview { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let request: Query
            if trimmed.isEmpty {
                request = db.collection("users")
                    .order(by: "name")
                    .limit(to: 20)
            } else {
                let end = "\(trimmed)\u{f8ff}"
                request = db.collection("users")
                    .order(by: "name")
                    .start(at: [trimmed])
                    .end(at: [end])
                    .limit(to: 20)
            }
            let docs = try await request.getDocuments()
            return docs.documents.compactMap { appUserFromDocument(id: $0.documentID, data: $0.data()) }
        } catch {
            AppLogger.error("searchUsers failed: \(error.localizedDescription)")
            return []
        }
    }

    func recommendUsers(for user: AppUser) async -> [AppUser] {
        if Self.isXcodePreview { return [] }
        do {
            async let queryUsers = db.collection("users").order(by: "name").limit(to: 80).getDocuments()
            async let myFollowingDocs = followingCollection(userId: user.id).getDocuments()
            async let mySignatureSnap = insightsSignatureRef(userId: user.id).getDocument()
            async let myProfileSnap = insightsProfileRef(userId: user.id).getDocument()

            let allUsers = try await queryUsers.documents
            let followingSet = Set(try await myFollowingDocs.documents.map(\.documentID))
            let mySignature = parseSignature(document: try await mySignatureSnap)
            let myProfileTags = parseHelpfulTags(document: try await myProfileSnap)
            let myTopEmotions = Set(mySignature?.topEmotions.map { $0.lowercased() } ?? [])

            var candidates: [(AppUser, Double)] = []
            for doc in allUsers {
                guard doc.documentID != user.id else { continue }
                guard !followingSet.contains(doc.documentID) else { continue }
                guard let appUser = appUserFromDocument(id: doc.documentID, data: doc.data()) else { continue }

                async let theirSignatureSnap = insightsSignatureRef(userId: appUser.id).getDocument()
                async let theirProfileSnap = insightsProfileRef(userId: appUser.id).getDocument()
                async let theirFollowerCount = fetchFollowerCount(userId: appUser.id)
                async let theirFollowingDocs = followingCollection(userId: appUser.id).limit(to: 120).getDocuments()

                let theirSignature = parseSignature(document: try await theirSignatureSnap)
                let theirTags = parseHelpfulTags(document: try await theirProfileSnap)
                let theirsTopEmotions = Set(theirSignature?.topEmotions.map { $0.lowercased() } ?? [])
                let theirFollowingSet = Set((try await theirFollowingDocs).documents.map(\.documentID))

                let emotionOverlap = Double(myTopEmotions.intersection(theirsTopEmotions).count)
                let sharedHelpfulTags = Double(myProfileTags.intersection(theirTags).count)
                let mutualConnectionsWeight = Double(followingSet.intersection(theirFollowingSet).count)
                let activityWeight = min(Double(try await theirFollowerCount), 25.0) / 25.0

                let score = (emotionOverlap * 0.4)
                    + (sharedHelpfulTags * 0.3)
                    + (mutualConnectionsWeight * 0.2)
                    + (activityWeight * 0.1)
                guard score > 0 else { continue }
                candidates.append((appUser, score))
            }
            return candidates
                .sorted { lhs, rhs in
                    if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                    return lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending
                }
                .prefix(20)
                .map(\.0)
        } catch {
            AppLogger.error("recommendUsers failed: \(error.localizedDescription)")
            return []
        }
    }

    private func parseSignature(document: DocumentSnapshot) -> UserEmotionalSignature? {
        guard let data = document.data() else { return nil }
        let averageIntensity = (data["averageIntensity"] as? Double)
            ?? (data["averageIntensity"] as? NSNumber)?.doubleValue
            ?? 0
        let topEmotions = data["topEmotions"] as? [String] ?? []
        let topHelpfulTags = data["topHelpfulTags"] as? [String] ?? []
        let sampleSize = FirestoreManager.intFromFirestore(data["sampleSize"])
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        return UserEmotionalSignature(
            averageIntensity: averageIntensity,
            topEmotions: topEmotions,
            topHelpfulTags: topHelpfulTags,
            sampleSize: sampleSize,
            updatedAt: updatedAt
        )
    }

    private func parseHelpfulTags(document: DocumentSnapshot) -> Set<String> {
        guard let data = document.data(),
              let raw = data["helpfulTagCounts"] as? [String: Any]
        else { return [] }
        return Set(raw.keys.map { $0.lowercased() })
    }

    private func fetchUsersByIds(_ ids: [String]) async -> [AppUser] {
        if ids.isEmpty { return [] }
        var users: [AppUser] = []
        for id in ids {
            if let user = await fetchAppUserProfile(userId: id) {
                users.append(user)
            }
        }
        return users
    }

    private func appUserFromDocument(id: String, data: [String: Any]) -> AppUser? {
        let name = (data["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty { return nil }
        let email = data["email"] as? String ?? ""
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let checkInStreak = FirestoreManager.intFromFirestore(data["checkInStreak"])
        let lastCheckInDate = (data["lastCheckInDate"] as? Timestamp)?.dateValue()
        let postCount = FirestoreManager.intFromFirestore(data["postCount"])
        let followerCount = FirestoreManager.intFromFirestore(data["followerCount"])
        let followingCount = FirestoreManager.intFromFirestore(data["followingCount"])
        return AppUser(
            id: id,
            name: name,
            email: email,
            createdAt: createdAt,
            postCount: postCount,
            followerCount: followerCount,
            followingCount: followingCount,
            checkInStreak: checkInStreak,
            lastCheckInDate: lastCheckInDate
        )
    }

    func setFollowing(currentUserId: String, targetUserId: String, follow: Bool) async throws {
        if follow {
            try await followUser(currentUserId: currentUserId, targetUserId: targetUserId)
        } else {
            try await unfollowUser(currentUserId: currentUserId, targetUserId: targetUserId)
        }
    }

    func followUser(currentUserId: String, targetUserId: String) async throws {
        guard currentUserId != targetUserId else { return }
        _ = try requireAuthUser(matchingExpectedUid: currentUserId)
        try await runWrite(successLog: "Now following user") {
            let currentRef = self.db.collection("users").document(currentUserId)
            let targetRef = self.db.collection("users").document(targetUserId)
            let followDocId = "\(currentUserId)__\(targetUserId)"
            let legacyFollowRef = self.db.collection("follows").document(followDocId)
            let followerEdgeRef = self.followersCollection(userId: targetUserId).document(currentUserId)
            let followingEdgeRef = self.followingCollection(userId: currentUserId).document(targetUserId)
            let alreadyFollowing = try await followingEdgeRef.getDocument()
            guard !alreadyFollowing.exists else {
                self.followingIds.insert(targetUserId)
                return
            }

            let batch = self.db.batch()
            batch.setData([
                "followerId": currentUserId,
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: followerEdgeRef, merge: true)
            batch.setData([
                "followingId": targetUserId,
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: followingEdgeRef, merge: true)
            batch.setData([
                "followerId": currentUserId,
                "followingId": targetUserId,
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: legacyFollowRef, merge: true)
            batch.setData([
                "following": FieldValue.arrayUnion([targetUserId]),
                "followingCount": FieldValue.increment(Int64(1))
            ], forDocument: currentRef, merge: true)
            batch.setData([
                "followerCount": FieldValue.increment(Int64(1))
            ], forDocument: targetRef, merge: true)
            try await batch.commit()
            followingIds.insert(targetUserId)
        }
    }

    func unfollowUser(currentUserId: String, targetUserId: String) async throws {
        guard currentUserId != targetUserId else { return }
        _ = try requireAuthUser(matchingExpectedUid: currentUserId)
        try await runWrite(successLog: "Unfollowed user") {
            let currentRef = self.db.collection("users").document(currentUserId)
            let targetRef = self.db.collection("users").document(targetUserId)
            let followDocId = "\(currentUserId)__\(targetUserId)"
            let legacyFollowRef = self.db.collection("follows").document(followDocId)
            let followerEdgeRef = self.followersCollection(userId: targetUserId).document(currentUserId)
            let followingEdgeRef = self.followingCollection(userId: currentUserId).document(targetUserId)
            let existing = try await followingEdgeRef.getDocument()
            guard existing.exists else {
                self.followingIds.remove(targetUserId)
                return
            }

            let batch = self.db.batch()
            batch.deleteDocument(followerEdgeRef)
            batch.deleteDocument(followingEdgeRef)
            batch.deleteDocument(legacyFollowRef)
            batch.setData([
                "following": FieldValue.arrayRemove([targetUserId]),
                "followingCount": FieldValue.increment(Int64(-1))
            ], forDocument: currentRef, merge: true)
            batch.setData([
                "followerCount": FieldValue.increment(Int64(-1))
            ], forDocument: targetRef, merge: true)
            try await batch.commit()
            followingIds.remove(targetUserId)
        }
    }

    // MARK: - Daily post limit

    private static func startAndEndOfLocalToday() -> (start: Date, end: Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return (start, end)
    }

    /// Counts posts authored by `userId` whose `createdAt` falls within the current local calendar day.
    func postsCreatedTodayCount(forUserId userId: String) async throws -> Int {
        if Self.isXcodePreview { return 0 }
        let range = Self.startAndEndOfLocalToday()
        let snapshot = try await db.collection("posts")
            .whereField("userId", isEqualTo: userId)
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: range.start))
            .whereField("createdAt", isLessThan: Timestamp(date: range.end))
            .getDocuments()
        return snapshot.documents.count
    }

    /// `true` if the user may create another post today (max 3 per local day).
    func canCreatePost(userId: String) async -> Bool {
        if Self.isXcodePreview || isUITestMode { return true }
        do {
            let n = try await postsCreatedTodayCount(forUserId: userId)
            if n >= 3 {
                print("🚫 Daily post limit (3) reached for user \(userId)")
                return false
            }
            return true
        } catch {
            print("❌ postsCreatedTodayCount failed:", error.localizedDescription)
            // Fail open so a missing Firestore index doesn’t brick posting; check console / add composite index.
            return true
        }
    }

    // MARK: - Create post (from check-in)

    /// Creates a feed post. Never throws — returns `false` and sets `errorMessage` on any failure (no force unwraps).
    func createPost(
        from checkIn: CheckInData,
        authorId: String,
        authorName: String,
        helpfulTags: [String]? = nil
    ) async -> Bool {
        if isUITestMode {
            let post = makeUITestPost(
                from: checkIn,
                authorId: authorId,
                authorName: authorName,
                helpfulTags: helpfulTags
            )
            posts.insert(post, at: 0)
            allPostsRaw = posts
            print("[POST] UI test local post created: \(post.id)")
            return true
        }
        if Self.isXcodePreview {
            print("[POST] createPost skipped in Xcode Preview")
            return false
        }

        guard let user = Auth.auth().currentUser else {
            print("[ERROR] No authenticated user for post create")
            errorMessage = "You must be signed in."
            return false
        }
        guard user.uid == authorId else {
            print("[ERROR] Auth user mismatch for post create")
            errorMessage = "Session error. Please sign in again."
            return false
        }

        let trimmedName = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            print("[ERROR] Invalid post payload: empty userName")
            errorMessage = "Profile name is missing. Update your profile and try again."
            return false
        }

        let insight = checkIn.emotionalInsight.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = checkIn.weeklyEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let whoops = checkIn.whoopsText.trimmingCharacters(in: .whitespacesAndNewlines)
        let weekly = checkIn.weeklyGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        let monthly = checkIn.monthlyGoal.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasContent = !emoji.isEmpty || !insight.isEmpty || !whoops.isEmpty || !weekly.isEmpty || !monthly.isEmpty
        guard hasContent else {
            print("[ERROR] Invalid post payload: no usable content")
            errorMessage = "Add an emoji or something about your week before posting."
            return false
        }

        print("[POST] Creating post for user: \(user.uid)")

        var reactionsPayload: [String: Any] = [:]
        for (key, count) in FirestoreManager.defaultReactionCounts() {
            reactionsPayload[key] = count
        }

        if checkIn.visibility == .groups {
            let g = checkIn.sharedGroupIds ?? []
            guard !g.isEmpty else {
                print("[ERROR] Group visibility missing selected group")
                errorMessage = "Choose a group to share with."
                return false
            }
        }

        let goalLine: String = weekly.isEmpty ? monthly : weekly
        let displayEmoji = emoji.isEmpty ? "✨" : emoji
        let trimmedTitle = checkIn.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? "Daily reflection 🌿" : trimmedTitle

        var uploadedImageURL = ""
        if let image = checkIn.checkInImage {
            do {
                let url = try await uploadImage(image, userId: authorId)
                uploadedImageURL = url.absoluteString
            } catch {
                if (error as NSError).code == 501 {
                    errorMessage = error.localizedDescription
                } else {
                    errorMessage = "Couldn't upload image. Please try again."
                }
                AppLogger.error("Image upload failed: \(error.localizedDescription)")
                return false
            }
        }

        var data: [String: Any] = [
            "userId": authorId,
            /// Explicit author for rules / queries that expect `authorId` (mirrors `userId`).
            "authorId": authorId,
            "userName": trimmedName,
            "weeklyEmoji": displayEmoji,
            "emotionalInsight": insight,
            "whoopsText": whoops,
            "weeklyGoal": goalLine,
            "title": resolvedTitle,
            "imageURL": uploadedImageURL,
            "weekNumber": checkIn.weekNumber,
            "selectedEmotions": checkIn.selectedEmotionsOrdered.isEmpty
                ? Array(checkIn.selectedEmotions).sorted()
                : checkIn.selectedEmotionsOrdered,
            "createdAt": checkIn.manualEntry ? Timestamp(date: checkIn.date) : FieldValue.serverTimestamp(),
            "likeCount": 0,
            "likedBy": [] as [String],
            "reactions": reactionsPayload,
            "userReactions": [:] as [String: String],
            "reactionUsers": [:] as [String: String],
            "visibility": checkIn.visibility.rawValue,
            "commentCount": 0,
            "manualEntry": checkIn.manualEntry,
            "softSupportCounts": Dictionary(uniqueKeysWithValues: SoftSupportReactionKind.allCases.map { ($0.rawValue, 0) }),
            "softSupportByUser": [:] as [String: [String]]
        ]
        if let intensity = checkIn.intensity {
            data["intensity"] = intensity
        }
        if let tip = checkIn.whatHelped?.trimmingCharacters(in: .whitespacesAndNewlines), !tip.isEmpty {
            data["whatHelped"] = tip
            data["helpfulText"] = tip
        }
        let autoTags = HelpfulTagger.extractTags(from: checkIn.whatHelped ?? "")
        let mergedHelpfulTags = Array(
            Set((checkIn.helpfulTags ?? []) + (helpfulTags ?? []) + autoTags)
        ).sorted()
        if !mergedHelpfulTags.isEmpty {
            data["helpfulTags"] = mergedHelpfulTags
        }
        if let g = checkIn.sharedGroupIds, !g.isEmpty {
            data["sharedGroupIds"] = g
        }

        do {
            let ref = db.collection("posts").document()
            try await ref.setData(data, merge: true)
            print("[POST] Post created successfully")
            do {
                try await db.collection("users").document(authorId).setData([
                    "postCount": FieldValue.increment(Int64(1))
                ], merge: true)
            } catch {
                AppLogger.error("Post count increment failed: \(error.localizedDescription)")
            }
            if !mergedHelpfulTags.isEmpty {
                do {
                    try await updateHelpfulProfile(userId: authorId, tags: mergedHelpfulTags)
                } catch {
                    AppLogger.error("Helpful profile update failed: \(error.localizedDescription)")
                }
            }
            do {
                try await updateUserSignature(userId: authorId, latestCheckIn: checkIn, helpfulTags: mergedHelpfulTags)
            } catch {
                AppLogger.error("Emotional signature update failed: \(error.localizedDescription)")
            }
            do {
                try await refreshSmartNudge(userId: authorId, latestCheckIn: checkIn)
            } catch {
                AppLogger.error("Smart nudge update failed: \(error.localizedDescription)")
            }
            if authorId == profileCacheUserId {
                cachedHelpfulProfile = await fetchUserHelpfulProfile(userId: authorId)
            }
            errorMessage = nil
            return true
        } catch {
            let msg = error.localizedDescription
            print("[ERROR] Post creation failed: \(msg)")
            errorMessage = msg
            return false
        }
    }

    private func updateHelpfulProfile(userId: String, tags: [String]) async throws {
        guard !tags.isEmpty else { return }
        let ref = helpfulInsightsProfileRef(userId: userId)
        let snap = try await ref.getDocument()
        let existing = (snap.data()?["helpfulTagCounts"] as? [String: Any]) ?? [:]
        var counts: [String: Int] = [:]
        for (key, value) in existing {
            counts[key.lowercased()] = FirestoreManager.intFromFirestore(value)
        }
        for tag in tags.map({ $0.lowercased() }) {
            counts[tag, default: 0] += 1
        }
        try await ref.setData([
            "helpfulTagCounts": counts,
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func updateUserSignature(userId: String, latestCheckIn: CheckInData, helpfulTags: [String]) async throws {
        let historical = wrapupHistoryEntries(forUserId: userId)
        let latest = CheckInData(
            userName: latestCheckIn.userName,
            astrologySign: latestCheckIn.astrologySign,
            weekNumber: latestCheckIn.weekNumber,
            weeklyEmoji: latestCheckIn.weeklyEmoji,
            checkInImage: nil,
            selectedEmotions: latestCheckIn.selectedEmotions,
            emotionalInsight: latestCheckIn.emotionalInsight,
            whoopsText: latestCheckIn.whoopsText,
            poopsText: latestCheckIn.poopsText,
            weeklyGoal: latestCheckIn.weeklyGoal,
            monthlyGoal: latestCheckIn.monthlyGoal,
            profileImage: nil,
            checkInVideoURL: nil,
            drawingImage: nil,
            visibility: latestCheckIn.visibility,
            date: Date(),
            intensity: latestCheckIn.intensity,
            whatHelped: latestCheckIn.whatHelped,
            manualEntry: latestCheckIn.manualEntry,
            helpfulTags: helpfulTags.isEmpty ? latestCheckIn.helpfulTags : helpfulTags,
            sharedGroupIds: latestCheckIn.sharedGroupIds,
            title: latestCheckIn.title,
            imageURL: latestCheckIn.imageURL,
            selectedEmotionsOrdered: latestCheckIn.selectedEmotionsOrdered
        )
        let signature = buildUserSignature(entries: [latest] + historical)
        try await emotionalSignatureRef(userId: userId).setData(signature.asFirestoreDictionary(), merge: true)
    }

    private func buildUserSignature(entries: [CheckInData]) -> UserEmotionalSignature {
        guard !entries.isEmpty else { return UserEmotionalSignature() }

        var emotionCounts: [String: Int] = [:]
        var tagCounts: [String: Int] = [:]
        var intensities: [Int] = []

        for entry in entries {
            for emotion in entry.selectedEmotions {
                let key = emotion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !key.isEmpty else { continue }
                emotionCounts[key, default: 0] += 1
            }
            for tag in (entry.helpfulTags ?? []) {
                let key = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !key.isEmpty else { continue }
                tagCounts[key, default: 0] += 1
            }
            if let intensity = entry.intensity {
                intensities.append(intensity)
            }
        }

        let avgIntensity: Double = intensities.isEmpty
            ? 0
            : Double(intensities.reduce(0, +)) / Double(intensities.count)

        let topEmotions = emotionCounts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(5)
            .map(\.key)

        let topTags = tagCounts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(5)
            .map(\.key)

        return UserEmotionalSignature(
            averageIntensity: avgIntensity,
            topEmotions: topEmotions,
            topHelpfulTags: topTags,
            sampleSize: entries.count,
            updatedAt: Date()
        )
    }

    func detectEmotionalPattern(entries: [CheckInData]) -> EmotionalPattern? {
        let sorted = entries.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return nil }

        let recent = Array(sorted.suffix(5))
        var highIntensityStreak = 0
        for entry in recent.reversed() {
            if (entry.intensity ?? 0) >= 8 {
                highIntensityStreak += 1
            } else {
                break
            }
        }
        if highIntensityStreak >= 3 {
            return EmotionalPattern(
                kind: "high_intensity_streak",
                message: "Your stress has been elevated for a few days. Try a gentle reset.",
                suggestedActions: ["walk", "rest", "breathe"]
            )
        }

        let tracked = ["anxious", "sad", "overwhelmed", "lonely"]
        let recentLabels = recent.map { $0.firstSelectedEmotionLabel.lowercased() }
        for emotion in tracked {
            let count = recentLabels.filter { $0.contains(emotion) }.count
            if count >= 3 {
                return EmotionalPattern(
                    kind: "\(emotion)_streak",
                    message: "You have felt \(emotion) often this week. A small supportive action can help.",
                    suggestedActions: emotion == "anxious" ? ["walk", "breathe", "journal"] : ["talk", "rest", "journal"]
                )
            }
        }
        return nil
    }

    private func refreshSmartNudge(userId: String, latestCheckIn: CheckInData) async throws {
        let entries = [latestCheckIn] + wrapupHistoryEntries(forUserId: userId)
        guard let pattern = detectEmotionalPattern(entries: entries) else {
            if activeNudge != nil { activeNudge = nil }
            return
        }
        let message = "\(pattern.message) Suggested: \(pattern.suggestedActions.joined(separator: ", "))"
        activeNudge = message
        let ref = nudgesRef(userId: userId).document()
        try await ref.setData([
            "kind": pattern.kind,
            "message": pattern.message,
            "suggestedActions": pattern.suggestedActions,
            "createdAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func refreshActiveNudge(userId: String) async {
        if Self.isXcodePreview {
            activeNudge = nil
            return
        }
        do {
            let snap = try await nudgesRef(userId: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 1)
                .getDocuments()
            guard let doc = snap.documents.first else {
                activeNudge = nil
                return
            }
            let data = doc.data()
            let message = data["message"] as? String ?? ""
            let actions = data["suggestedActions"] as? [String] ?? []
            activeNudge = message.isEmpty ? nil : "\(message) Suggested: \(actions.joined(separator: ", "))"
        } catch {
            AppLogger.error("refreshActiveNudge failed: \(error.localizedDescription)")
            activeNudge = nil
        }
    }

    // MARK: - Like (transaction, no duplicate likes)

    func toggleLike(postId: String, userId: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        try await runWrite(successLog: "Like updated") {
            try await self.performToggleLike(postId: postId, userId: userId)
        }
    }

    private func performToggleLike(postId: String, userId: String) async throws {
        let docRef = db.collection("posts").document(postId)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                do {
                    let snapshot = try transaction.getDocument(docRef)
                    guard snapshot.exists, let data = snapshot.data() else {
                        throw NSError(domain: "FirestoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"])
                    }
                    var likedBy = data["likedBy"] as? [String] ?? []
                    var likeCount = data["likeCount"] as? Int ?? FirestoreManager.intFromFirestore(data["likeCount"])
                    var likedSet = Set(likedBy)
                    if likedSet.contains(userId) {
                        likedSet.remove(userId)
                        likeCount = max(0, likeCount - 1)
                    } else {
                        likedSet.insert(userId)
                        likeCount += 1
                    }
                    likedBy = Array(likedSet)
                    transaction.updateData([
                        "likedBy": likedBy,
                        "likeCount": likeCount
                    ], forDocument: docRef)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    // MARK: - Reactions (transaction: one per user, toggle same, switch emoji)

    func applyReaction(postId: String, userId: String, emoji: String) async throws {
        if isUITestMode {
            if let idx = posts.firstIndex(where: { $0.id == postId }) {
                var post = posts[idx]
                let previous = post.userReactions[userId]
                if previous == emoji {
                    post.userReactions[userId] = nil
                    post.reactions[emoji] = max(0, (post.reactions[emoji] ?? 0) - 1)
                } else if let previous {
                    post.reactions[previous] = max(0, (post.reactions[previous] ?? 0) - 1)
                    post.reactions[emoji, default: 0] += 1
                    post.userReactions[userId] = emoji
                } else {
                    post.reactions[emoji, default: 0] += 1
                    post.userReactions[userId] = emoji
                }
                posts[idx] = post
                allPostsRaw = posts
            }
            print("[REACTION] UI test local reaction applied post=\(postId) emoji=\(emoji)")
            return
        }
        _ = try requireAuthUser(matchingExpectedUid: userId)
        AppLogger.log("[REACTION] Applying reaction \(emoji) on post \(postId)")
        try await runWrite(successLog: "Reaction updated") {
            try await self.performApplyReaction(postId: postId, userId: userId, emoji: emoji)
        }
    }

    private func makeUITestPost(
        from checkIn: CheckInData,
        authorId: String,
        authorName: String,
        helpfulTags: [String]? = nil
    ) -> FeedPost {
        let insight = checkIn.emotionalInsight.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = checkIn.weeklyEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let whoops = checkIn.whoopsText.trimmingCharacters(in: .whitespacesAndNewlines)
        let weekly = checkIn.weeklyGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        let monthly = checkIn.monthlyGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        let goalLine = weekly.isEmpty ? monthly : weekly
        let selected = checkIn.selectedEmotionsOrdered.isEmpty
            ? Array(checkIn.selectedEmotions).sorted()
            : checkIn.selectedEmotionsOrdered

        let autoTags = HelpfulTagger.extractTags(from: checkIn.whatHelped ?? "")
        let mergedHelpfulTags = Array(
            Set((checkIn.helpfulTags ?? []) + (helpfulTags ?? []) + autoTags)
        ).sorted()

        return FeedPost(
            id: "ui_post_\(UUID().uuidString)",
            authorId: authorId,
            user: FeedUser(id: authorId, name: authorName, streak: 0),
            emoji: emoji.isEmpty ? "✨" : emoji,
            insight: insight,
            whoop: whoops,
            goal: goalLine,
            title: checkIn.title,
            imageURL: checkIn.imageURL,
            selectedEmotions: selected,
            visibility: checkIn.visibility,
            intensity: checkIn.intensity,
            whatHelped: checkIn.whatHelped,
            helpfulTags: mergedHelpfulTags,
            createdAt: Date()
        )
    }

    func topHelpfulTagsThisWeek() -> [String] {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let recent = posts.filter {
            guard let date = $0.createdAt else { return false }
            return date > cutoff
        }
        var counts: [String: Int] = [:]
        for post in recent {
            for tag in post.helpfulTags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
            .sorted { $0.value > $1.value }
            .map(\.key)
            .prefix(3)
            .map { $0 }
    }

    func uploadImage(_ image: UIImage, userId: String) async throws -> URL {
#if canImport(FirebaseStorage)
        print("📤 Uploading image for user: \(userId)")
        guard let data = image.jpegData(compressionQuality: 0.84) else {
            throw NSError(domain: "FirestoreManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        let path = "post_images/\(userId)/\(UUID().uuidString).jpg"
        print("📤 Upload path: \(path)")
        let ref = Storage.storage().reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.putData(data, metadata: metadata) { _, error in
                if let error {
                    print("❌ Firebase Storage upload error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ Firebase Storage upload succeeded for path: \(path)")
                    continuation.resume(returning: ())
                }
            }
        }

        let downloadURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            ref.downloadURL { url, error in
                if let error {
                    print("❌ Firebase Storage downloadURL error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if let url {
                    print("✅ Firebase Storage URL: \(url.absoluteString)")
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: NSError(domain: "FirestoreManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Missing download URL"]))
                }
            }
        }
        return downloadURL
#else
        let message = "FirebaseStorage SDK is not linked. Add FirebaseStorage to the app target to enable image uploads."
        AppLogger.error(message)
        throw NSError(
            domain: "FirestoreManager",
            code: 501,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
#endif
    }

    private func performApplyReaction(postId: String, userId: String, emoji: String) async throws {
        let docRef = db.collection("posts").document(postId)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                do {
                    let snapshot = try transaction.getDocument(docRef)
                    guard snapshot.exists, let data = snapshot.data() else {
                        throw NSError(domain: "FirestoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"])
                    }
                    var reactions = FirestoreManager.normalizeReactions(data["reactions"] as? [String: Any])
                    var userReactions = (data["userReactions"] as? [String: String] ?? [:])
                        .merging(data["reactionUsers"] as? [String: String] ?? [:]) { existing, _ in existing }
                    let previous = userReactions[userId]

                    if previous == emoji {
                        userReactions[userId] = nil
                        reactions[emoji] = max(0, (reactions[emoji] ?? 0) - 1)
                    } else if let prev = previous {
                        reactions[prev] = max(0, (reactions[prev] ?? 0) - 1)
                        reactions[emoji, default: 0] += 1
                        userReactions[userId] = emoji
                    } else {
                        reactions[emoji, default: 0] += 1
                        userReactions[userId] = emoji
                    }

                    transaction.updateData([
                        "reactions": reactions,
                        "userReactions": userReactions,
                        "reactionUsers": userReactions
                    ], forDocument: docRef)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    // MARK: - Soft support reactions (`posts/{id}/reactions` + denormalized post fields)

    func toggleSoftSupportReaction(postId: String, userId: String, kind: SoftSupportReactionKind) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        if Self.isXcodePreview {
            // Keep Previews responsive: update local cache only.
            var list = allPostsRaw
            guard let idx = list.firstIndex(where: { $0.id == postId }) else { return }
            var p = list[idx]
            let key = kind.rawValue
            var types = p.softSupportByUser[userId] ?? []
            if let i = types.firstIndex(of: key) {
                types.remove(at: i)
                p.softSupportCounts[key] = max(0, (p.softSupportCounts[key] ?? 1) - 1)
            } else {
                if !types.contains(key) { types.append(key) }
                p.softSupportCounts[key, default: 0] += 1
            }
            if types.isEmpty {
                p.softSupportByUser.removeValue(forKey: userId)
            } else {
                p.softSupportByUser[userId] = types
            }
            list[idx] = p
            allPostsRaw = list
            applyPostVisibilityFilter()
            return
        }
        try await runWrite(successLog: "Soft support reaction updated") {
            try await self.performToggleSoftSupport(postId: postId, userId: userId, kind: kind)
        }
    }

    private func performToggleSoftSupport(postId: String, userId: String, kind: SoftSupportReactionKind) async throws {
        let postRef = db.collection("posts").document(postId)
        let reactionId = SoftSupportReactionKind.documentId(userId: userId, kind: kind)
        let reactionRef = postRef.collection("reactions").document(reactionId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                do {
                    let postSnap = try transaction.getDocument(postRef)
                    guard postSnap.exists, var pdata = postSnap.data() else {
                        throw NSError(domain: "FirestoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"])
                    }

                    var counts: [String: Int] = [:]
                    if let raw = pdata["softSupportCounts"] as? [String: Any] {
                        for (k, v) in raw {
                            counts[k] = FirestoreManager.intFromFirestore(v)
                        }
                    }
                    for k in SoftSupportReactionKind.allCases.map(\.rawValue) where counts[k] == nil {
                        counts[k] = 0
                    }

                    var byUser: [String: [String]] = [:]
                    if let raw = pdata["softSupportByUser"] as? [String: Any] {
                        for (uid, val) in raw {
                            if let arr = val as? [String] {
                                byUser[uid] = arr
                            }
                        }
                    }

                    let reactionSnap = try transaction.getDocument(reactionRef)
                    let exists = reactionSnap.exists
                    let typeKey = kind.rawValue

                    if exists {
                        transaction.deleteDocument(reactionRef)
                        counts[typeKey] = max(0, (counts[typeKey] ?? 1) - 1)
                        var arr = byUser[userId] ?? []
                        arr.removeAll { $0 == typeKey }
                        if arr.isEmpty {
                            byUser.removeValue(forKey: userId)
                        } else {
                            byUser[userId] = arr
                        }
                    } else {
                        transaction.setData([
                            "userId": userId,
                            "type": typeKey,
                            "createdAt": FieldValue.serverTimestamp()
                        ], forDocument: reactionRef)
                        counts[typeKey, default: 0] += 1
                        var arr = byUser[userId] ?? []
                        if !arr.contains(typeKey) { arr.append(typeKey) }
                        byUser[userId] = arr
                    }

                    transaction.updateData([
                        "softSupportCounts": counts,
                        "softSupportByUser": byUser
                    ], forDocument: postRef)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    // MARK: - Profile details (`users/{uid}/profile/details`)

    private func userProfileDetailsRef(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("profile").document("details")
    }

    func fetchProfileDetails(userId: String) async -> ProfileDetails? {
        if Self.isXcodePreview { return nil }
        do {
            let snap = try await userProfileDetailsRef(userId: userId).getDocument()
            guard snap.exists, let data = snap.data() else { return nil }
            return try ProfileDetails.fromFirestoreDictionary(data)
        } catch {
            print("⚠️ fetchProfileDetails: \(error.localizedDescription)")
            return nil
        }
    }

    func saveProfileDetails(_ details: ProfileDetails, userId: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        try await runWrite(successLog: "Profile details saved") {
            let payload = try details.asFirestoreDictionary()
            try await self.userProfileDetailsRef(userId: userId).setData(payload, merge: true)
        }
    }

    /// `true` when Firestore has at least `minimum` documents authored by this user.
    func hasAtLeastPosts(authorId: String, minimum: Int) async -> Bool {
        if Self.isXcodePreview { return false }
        guard minimum > 0 else { return true }
        do {
            let snap = try await db.collection("posts")
                .whereField("authorId", isEqualTo: authorId)
                .limit(to: minimum)
                .getDocuments()
            return snap.documents.count >= minimum
        } catch {
            print("⚠️ hasAtLeastPosts: \(error.localizedDescription)")
            return false
        }
    }

    /// Recent thumbs on / off recommendations—the scoring engine uses this as a signal.
    func fetchRecommendationFeedbackSummary(userId: String, limit: Int = 36) async -> [(title: String, helpful: Bool)] {
        if Self.isXcodePreview { return [] }
        do {
            let snap = try await db.collection("users").document(userId).collection("recommendationFeedback")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { doc -> (title: String, helpful: Bool)? in
                let d = doc.data()
                guard let title = d["title"] as? String, let helpful = d["helpful"] as? Bool else { return nil }
                return (title: title, helpful: helpful)
            }
        } catch {
            print("⚠️ fetchRecommendationFeedbackSummary: \(error.localizedDescription)")
            return []
        }
    }

    func fetchUserHelpfulProfile(userId: String) async -> [String: Int] {
        if Self.isXcodePreview { return [:] }
        do {
            let snap = try await helpfulInsightsProfileRef(userId: userId).getDocument()
            guard let data = snap.data(),
                  let raw = data["helpfulTagCounts"] as? [String: Any]
            else { return [:] }

            var counts: [String: Int] = [:]
            for (tag, value) in raw {
                counts[tag.lowercased()] = FirestoreManager.intFromFirestore(value)
            }
            return counts
        } catch {
            AppLogger.error("fetchUserHelpfulProfile failed: \(error.localizedDescription)")
            return [:]
        }
    }

    private func recommendationMemoryRef(userId: String, recommendationId: String) -> DocumentReference {
        db.collection("users")
            .document(userId)
            .collection("recommendationMemory")
            .document(recommendationId)
    }

    private func habitSignalsRef(userId: String) -> CollectionReference {
        db.collection("users")
            .document(userId)
            .collection("habitSignals")
    }

    func fetchRecommendationMemory(userId: String, limit: Int = 300) async -> [String: RecommendationMemory] {
        if Self.isXcodePreview { return [:] }
        do {
            let snap = try await db.collection("users").document(userId).collection("recommendationMemory")
                .limit(to: limit)
                .getDocuments()
            var out: [String: RecommendationMemory] = [:]
            for doc in snap.documents {
                do {
                    let memory = try RecommendationMemory.fromFirestoreDictionary(doc.data(), fallbackRecommendationId: doc.documentID)
                    out[doc.documentID] = memory
                } catch {
                    print("⚠️ recommendation memory decode [\(doc.documentID)]: \(error.localizedDescription)")
                }
            }
            return out
        } catch {
            print("⚠️ fetchRecommendationMemory: \(error.localizedDescription)")
            return [:]
        }
    }

    private func updateRecommendationMemory(
        userId: String,
        recommendationId: String,
        mutate: (inout RecommendationMemory) -> Void
    ) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        try await runWrite(successLog: "Recommendation memory updated") {
            let ref = self.recommendationMemoryRef(userId: userId, recommendationId: recommendationId)
            let snap = try await ref.getDocument()
            var memory: RecommendationMemory
            if let data = snap.data() {
                memory = (try? RecommendationMemory.fromFirestoreDictionary(data, fallbackRecommendationId: recommendationId))
                    ?? RecommendationMemory(recommendationId: recommendationId)
            } else {
                memory = RecommendationMemory(recommendationId: recommendationId)
            }
            mutate(&memory)
            let payload = try memory.asFirestoreDictionary()
            try await ref.setData(payload, merge: true)
        }
    }

    func recordRecommendationShown(userId: String, recommendationId: String) async throws {
        try await updateRecommendationMemory(userId: userId, recommendationId: recommendationId) { memory in
            memory.timesShown += 1
            memory.lastShownAt = Date()
        }
    }

    func recordRecommendationAccepted(userId: String, recommendationId: String) async throws {
        try await updateRecommendationMemory(userId: userId, recommendationId: recommendationId) { memory in
            memory.timesAccepted += 1
            memory.streakAccepted += 1
            memory.lastAcceptedAt = Date()
        }
    }

    func recordRecommendationDismissed(userId: String, recommendationId: String) async throws {
        try await updateRecommendationMemory(userId: userId, recommendationId: recommendationId) { memory in
            memory.timesDismissed += 1
            memory.streakAccepted = 0
        }
    }

    func saveHabitSignal(_ signal: HabitSignal, userId: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        try await runWrite(successLog: "Habit signal saved") {
            let payload = try signal.asFirestoreDictionary()
            try await self.habitSignalsRef(userId: userId).document(signal.id.uuidString).setData(payload, merge: true)
        }
    }

    func fetchHabitSignals(userId: String, limit: Int = 180) async -> [HabitSignal] {
        if Self.isXcodePreview { return [] }
        do {
            let snap = try await habitSignalsRef(userId: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { doc in
                let sanitized = sanitizeFirestoreForJSON(doc.data())
                guard JSONSerialization.isValidJSONObject(sanitized),
                      let obj = sanitized as? [String: Any] else { return nil }
                return try? HabitSignal.fromFirestoreDictionary(obj)
            }
        } catch {
            print("⚠️ fetchHabitSignals: \(error.localizedDescription)")
            return []
        }
    }

    /// Lightweight moderation signal — `userReports/{autoId}`.
    func submitUserReport(reporterId: String, reportedUserId: String, reason: String?) async throws {
        _ = try requireAuthUser(matchingExpectedUid: reporterId)
        try await runWrite(successLog: "User report submitted") {
            _ = try await self.db.collection("userReports").addDocument(data: [
                "reporterId": reporterId,
                "reportedUserId": reportedUserId,
                "reason": reason ?? "",
                "createdAt": FieldValue.serverTimestamp()
            ])
        }
    }

    // MARK: - Helpers (shared with FeedPost mapping)

    static func defaultReactionCounts() -> [String: Int] {
        FeedReactions.defaultCounts
    }

    static func intFromFirestore(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let l = any as? Int64 { return Int(l) }
        if let d = any as? Double { return Int(d) }
        return 0
    }

    /// Converts Firestore-native values (Timestamp/Date/etc.) to JSON-safe values.
    private func sanitizeFirestoreForJSON(_ any: Any) -> Any {
        if let ts = any as? Timestamp {
            return ts.dateValue().timeIntervalSince1970
        }
        if let date = any as? Date {
            return date.timeIntervalSince1970
        }
        if let dict = any as? [String: Any] {
            var out: [String: Any] = [:]
            for (k, v) in dict {
                out[k] = sanitizeFirestoreForJSON(v)
            }
            return out
        }
        if let array = any as? [Any] {
            return array.map { sanitizeFirestoreForJSON($0) }
        }
        if let s = any as? String { return s }
        if let b = any as? Bool { return b }
        if let i = any as? Int { return i }
        if let l = any as? Int64 { return Int(l) }
        if let d = any as? Double { return d }
        if let n = any as? NSNumber { return n }
        if any is NSNull { return NSNull() }
        return String(describing: any)
    }

    static func normalizeReactions(_ dict: [String: Any]?) -> [String: Int] {
        var out = defaultReactionCounts()
        if let dict {
            for (k, v) in dict {
                out[k] = intFromFirestore(v)
            }
        }
        for k in FeedReactions.all where out[k] == nil {
            out[k] = 0
        }
        return out
    }

    // MARK: - User preferences (`users/{uid}/preferences/profile`)

    private func userPreferencesProfileRef(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("preferences").document("profile")
    }

    func fetchUserPreferences(userId: String) async -> UserPreferences? {
        if Self.isXcodePreview { return nil }
        do {
            let snap = try await userPreferencesProfileRef(userId: userId).getDocument()
            guard snap.exists, let data = snap.data() else { return nil }
            return try UserPreferences.fromFirestoreDictionary(data)
        } catch {
            print("⚠️ fetchUserPreferences: \(error.localizedDescription)")
            return nil
        }
    }

    func saveUserPreferences(_ preferences: UserPreferences, userId: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        try await runWrite(successLog: "User preferences saved") {
            let payload = try preferences.asFirestoreDictionary()
            try await self.userPreferencesProfileRef(userId: userId).setData(payload, merge: true)
        }
    }

    // MARK: - Profile + support

    private func userRootRef(userId: String) -> DocumentReference {
        db.collection("users").document(userId)
    }

    private func userPublicProfileRef(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("profile").document("main")
    }

    private func supportSettingsRef(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("support").document("settings")
    }

    private func supportInboxRef(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("supportInbox")
    }

    private func dopamineMenuRef(userId: String) -> DocumentReference {
        db.collection("dopamineMenus").document(userId)
    }

    private func helpfulInsightsProfileRef(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("insights").document("profile")
    }

    private func emotionalSignatureRef(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("insights").document("signature")
    }

    private func nudgesRef(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("nudges")
    }

    func fetchUserProfile(userId: String) async -> UserProfile? {
        if Self.isXcodePreview { return nil }
        do {
            let snap = try await userRootRef(userId: userId).getDocument()
            guard snap.exists, let data = snap.data() else { return nil }
            print("RAW FIRESTORE:", data)
            let sanitized = sanitizeFirestoreForJSON(data)
            guard JSONSerialization.isValidJSONObject(sanitized) else {
                print("⚠️ fetchUserProfile: sanitized payload is not valid JSON")
                return nil
            }
            let jsonData = try JSONSerialization.data(withJSONObject: sanitized, options: [])
            do {
                return try JSONDecoder().decode(UserProfile.self, from: jsonData)
            } catch {
                print("⚠️ fetchUserProfile decode: \(error.localizedDescription)")
                return nil
            }
        } catch {
            print("⚠️ fetchUserProfile: \(error.localizedDescription)")
            return nil
        }
    }

    func saveUserProfile(_ profile: UserProfile, userId: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        try await runWrite(successLog: "User profile saved") {
            let payload = try profile.asFirestoreDictionary()
            try await self.userRootRef(userId: userId).setData(payload, merge: true)
        }
    }

    func saveSupportSettings(_ settings: SupportSettings, userId: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        try await runWrite(successLog: "Support settings saved") {
            let payload = try settings.asFirestoreDictionary()
            try await self.supportSettingsRef(userId: userId).setData(payload, merge: true)
        }
    }

    func fetchSupportSettings(userId: String) async -> SupportSettings? {
        if Self.isXcodePreview { return nil }
        do {
            let snap = try await supportSettingsRef(userId: userId).getDocument()
            guard snap.exists, let data = snap.data() else { return nil }
            return try SupportSettings.fromFirestoreDictionary(data)
        } catch {
            print("⚠️ fetchSupportSettings: \(error.localizedDescription)")
            return nil
        }
    }

    /// Mutual relationship gate via `/follows` documents:
    /// `followerId` follows `followingId`.
    func isFriend(currentUserId: String, otherUserId: String) async -> Bool {
        if Self.isXcodePreview { return false }
        guard !currentUserId.isEmpty, !otherUserId.isEmpty, currentUserId != otherUserId else { return false }
        do {
            let a = try await db.collection("follows")
                .whereField("followerId", isEqualTo: currentUserId)
                .whereField("followingId", isEqualTo: otherUserId)
                .limit(to: 1)
                .getDocuments()
            guard !a.documents.isEmpty else { return false }

            let b = try await db.collection("follows")
                .whereField("followerId", isEqualTo: otherUserId)
                .whereField("followingId", isEqualTo: currentUserId)
                .limit(to: 1)
                .getDocuments()
            return !b.documents.isEmpty
        } catch {
            print("⚠️ isFriend: \(error.localizedDescription)")
            return false
        }
    }

    func sendSupportMessage(
        fromUserId: String,
        targetUserId: String,
        text: String?
    ) async throws {
        _ = try requireAuthUser(matchingExpectedUid: fromUserId)
        try await runWrite(successLog: "Support message sent") {
            try await supportInboxRef(userId: targetUserId).addDocument(data: [
                "fromUserId": fromUserId,
                "type": SupportInboxType.message.rawValue,
                "text": text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                "createdAt": FieldValue.serverTimestamp()
            ])
        }
    }

    func sendSupportInvite(
        fromUserId: String,
        targetUserId: String,
        activity: String
    ) async throws {
        _ = try requireAuthUser(matchingExpectedUid: fromUserId)
        let trimmed = activity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await runWrite(successLog: "Support invite sent") {
            try await supportInboxRef(userId: targetUserId).addDocument(data: [
                "fromUserId": fromUserId,
                "type": SupportInboxType.invite.rawValue,
                "activity": trimmed,
                "createdAt": FieldValue.serverTimestamp()
            ])
        }
    }

    func sendSupportGift(
        fromUserId: String,
        targetUserId: String,
        itemTitle: String,
        itemURL: String
    ) async throws {
        _ = try requireAuthUser(matchingExpectedUid: fromUserId)
        let title = itemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = itemURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !url.isEmpty else { return }
        try await runWrite(successLog: "Support gift sent") {
            try await supportInboxRef(userId: targetUserId).addDocument(data: [
                "fromUserId": fromUserId,
                "type": SupportInboxType.gift.rawValue,
                "itemTitle": title,
                "itemURL": url,
                "createdAt": FieldValue.serverTimestamp()
            ])
        }
    }

    func fetchSupportInbox(userId: String, limit: Int = 40) async -> [SupportInboxItem] {
        if Self.isXcodePreview { return [] }
        do {
            let snap = try await supportInboxRef(userId: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { SupportInboxItem($0) }
        } catch {
            print("⚠️ fetchSupportInbox: \(error.localizedDescription)")
            return []
        }
    }

    func fetchDopamineMenu(userId: String) async -> DopamineMenu? {
        if Self.isXcodePreview { return nil }
        do {
            let snap = try await dopamineMenuRef(userId: userId).getDocument()
            guard snap.exists, let data = snap.data() else { return nil }
            return try DopamineMenu.fromFirestoreDictionary(data)
        } catch {
            AppLogger.error("fetchDopamineMenu failed: \(error.localizedDescription)")
            return nil
        }
    }

    func saveDopamineMenu(userId: String, menu: DopamineMenu) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        try await runWrite(successLog: "Dopamine menu saved") {
            let payload = try menu.asFirestoreDictionary()
            try await self.dopamineMenuRef(userId: userId).setData(payload, merge: true)
        }
    }

    /// Full profile save used by `EditProfileView`.
    /// Writes:
    /// - `users/{userId}` (root: display identity)
    /// - `users/{userId}/profile/main` (public profile fields)
    /// - `users/{userId}/profile/details` (insight summary + extra details)
    func saveProfileSystem(
        userId: String,
        displayName: String,
        username: String,
        profile: UserProfile,
        details: ProfileDetails
    ) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        try await runWrite(successLog: "Profile system saved") {
            try await self.db.collection("users").document(userId).setData([
                "name": displayName,
                "username": username,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            let profilePayload = try profile.asFirestoreDictionary()
            try await self.userPublicProfileRef(userId: userId).setData(profilePayload, merge: true)

            let detailsPayload = try details.asFirestoreDictionary()
            try await self.userProfileDetailsRef(userId: userId).setData(detailsPayload, merge: true)
        }
    }

    func submitRecommendationFeedback(
        userId: String,
        recommendationId: String,
        helpful: Bool
    ) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        AppLogger.log("[RECOMMENDATION] Saving feedback rec=\(recommendationId) helpful=\(helpful)")
        try await runWrite(successLog: "Recommendation feedback saved") {
            let ref = self.db.collection("users").document(userId).collection("recommendationFeedback").document()
            try await ref.setData([
                "recommendationId": recommendationId,
                "helpful": helpful,
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }

    /// `users/{userId}/recommendationFeedback/{autoId}` — refine engine over time.
    func submitRecommendationFeedback(
        userId: String,
        recommendationId: String,
        title: String,
        reason: String,
        type: RecommendationType,
        helpful: Bool
    ) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        AppLogger.log("[RECOMMENDATION] Saving detailed feedback rec=\(recommendationId) helpful=\(helpful)")
        try await runWrite(successLog: "Recommendation feedback saved") {
            let ref = self.db.collection("users").document(userId).collection("recommendationFeedback").document()
            try await ref.setData([
                "recommendationId": recommendationId,
                "title": title,
                "reason": reason,
                "type": type.rawValue,
                "helpful": helpful,
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }

    /// Seeds demo users/posts only when the feed is empty.
    func seedFirestoreIfEmpty() async {
        await SeedDataManager.shared.seedFirestoreIfEmpty()
    }

    #if DEBUG
    func seedTestData() async {
        guard !isUITestMode else {
            applyPreviewPosts(SeedData.posts)
            return
        }
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        do {
            let existing = try await db.collection("posts").limit(to: 1).getDocuments()
            guard existing.documents.isEmpty else { return }

            let userDocs = SeedData.users.map { user -> [String: Any] in
                [
                    "id": user.id == "seed-user-1" ? currentUid : user.id,
                    "name": user.name,
                    "email": user.email,
                    "createdAt": Timestamp(date: user.createdAt),
                    "checkInStreak": user.checkInStreak
                ]
            }

            let batch = db.batch()
            for doc in userDocs {
                guard let id = doc["id"] as? String else { continue }
                batch.setData(doc, forDocument: db.collection("users").document(id), merge: true)
            }

            for post in SeedData.posts {
                let ownerId = post.authorId == "seed-user-1" ? currentUid : post.authorId
                let reactionMap = SeedData.reactions
                    .filter { $0.postId == post.id }
                    .reduce(into: [String: Int]()) { partial, reaction in
                        partial[reaction.emoji, default: 0] += 1
                    }
                let reactionUsers = SeedData.reactions
                    .filter { $0.postId == post.id }
                    .reduce(into: [String: String]()) { partial, reaction in
                        partial[reaction.userId == "seed-user-1" ? currentUid : reaction.userId] = reaction.emoji
                    }

                let payload: [String: Any] = [
                    "authorId": ownerId,
                    "userId": ownerId,
                    "userName": post.user.name,
                    "weeklyEmoji": post.emoji,
                    "emotionalInsight": post.insight,
                    "whoopsText": post.whoop,
                    "weeklyGoal": post.goal,
                    "selectedEmotions": post.selectedEmotions,
                    "createdAt": Timestamp(date: post.createdAt ?? Date()),
                    "likeCount": post.likeCount,
                    "likedBy": post.likedBy,
                    "reactions": FirestoreManager.defaultReactionCounts().merging(reactionMap, uniquingKeysWith: { _, new in new }),
                    "userReactions": reactionUsers,
                    "reactionUsers": reactionUsers,
                    "visibility": post.visibility.rawValue,
                    "commentCount": post.commentCount,
                    "intensity": post.intensity ?? 5,
                    "tags": post.tags
                ]
                batch.setData(payload, forDocument: db.collection("posts").document(post.id), merge: true)
            }

            try await batch.commit()
            AppLogger.log("[FIRESTORE] Seed test data complete")
        } catch {
            AppLogger.error("Seed test data failed: \(error.localizedDescription)")
        }
    }
    #endif
}
