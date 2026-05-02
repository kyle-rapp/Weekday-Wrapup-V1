import Foundation
import FirebaseAuth
import FirebaseFirestore

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

    /// Lazily created so Xcode Previews never touch Firestore unless a Firebase-backed method runs.
    private lazy var db: Firestore = Firestore.firestore()
    /// Latest documents from Firestore before visibility filtering.
    private var allPostsRaw: [FeedPost] = []
    private var postsListener: ListenerRegistration?
    private var commentsListener: ListenerRegistration?
    private var followingListener: ListenerRegistration?
    private var groupsListener: ListenerRegistration?

    private init() {}

    private static var isXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
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
            print("✅ \(successLog)")
            return value
        } catch {
            let msg = error.localizedDescription
            print("❌ Firestore error: \(msg)")
            errorMessage = msg
            throw error
        }
    }

    private func reportListenerError(_ context: String, error: Error) {
        let msg = error.localizedDescription
        print("❌ \(context): \(msg)")
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
        errorMessage = nil
    }

    // MARK: - Posts listener

    func startPostsListener() {
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

        return score
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

    func startFollowingListener(userId: String) {
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

    func setFollowing(currentUserId: String, targetUserId: String, follow: Bool) async throws {
        guard currentUserId != targetUserId else { return }
        _ = try requireAuthUser(matchingExpectedUid: currentUserId)
        try await runWrite(successLog: follow ? "Now following user" : "Unfollowed user") {
            let ref = self.db.collection("users").document(currentUserId)
            let followDocId = "\(currentUserId)__\(targetUserId)"
            let followRef = self.db.collection("follows").document(followDocId)
            if follow {
                try await ref.updateData(["following": FieldValue.arrayUnion([targetUserId])])
                try await followRef.setData([
                    "followerId": currentUserId,
                    "followingId": targetUserId,
                    "createdAt": FieldValue.serverTimestamp()
                ], merge: true)
            } else {
                try await ref.updateData(["following": FieldValue.arrayRemove([targetUserId])])
                try await followRef.delete()
            }
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
        if Self.isXcodePreview { return true }
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
    func createPost(from checkIn: CheckInData, authorId: String, authorName: String) async -> Bool {
        if Self.isXcodePreview {
            print("⚠️ createPost skipped (Xcode Preview)")
            return false
        }

        guard let user = Auth.auth().currentUser else {
            print("❌ No authenticated user")
            errorMessage = "You must be signed in."
            return false
        }
        guard user.uid == authorId else {
            print("❌ Auth user mismatch (signed-in uid vs authorId)")
            errorMessage = "Session error. Please sign in again."
            return false
        }

        let trimmedName = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            print("❌ Invalid post: empty userName")
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
            print("❌ Invalid post: no usable content (emoji, insight, whoops, or goals)")
            errorMessage = "Add an emoji or something about your week before posting."
            return false
        }

        print("🚀 Attempting to create post")
        print("User ID:", user.uid)

        var reactionsPayload: [String: Any] = [:]
        for (key, count) in FirestoreManager.defaultReactionCounts() {
            reactionsPayload[key] = count
        }

        if checkIn.visibility == .groups {
            let g = checkIn.sharedGroupIds ?? []
            guard !g.isEmpty else {
                print("❌ Groups visibility requires at least one group")
                errorMessage = "Choose a group to share with."
                return false
            }
        }

        let goalLine: String = weekly.isEmpty ? monthly : weekly
        let displayEmoji = emoji.isEmpty ? "✨" : emoji

        var data: [String: Any] = [
            "userId": authorId,
            /// Explicit author for rules / queries that expect `authorId` (mirrors `userId`).
            "authorId": authorId,
            "userName": trimmedName,
            "weeklyEmoji": displayEmoji,
            "emotionalInsight": insight,
            "whoopsText": whoops,
            "weeklyGoal": goalLine,
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
        if let tags = checkIn.helpfulTags, !tags.isEmpty {
            data["helpfulTags"] = tags
        }
        if let g = checkIn.sharedGroupIds, !g.isEmpty {
            data["sharedGroupIds"] = g
        }

        do {
            let ref = db.collection("posts").document()
            try await ref.setData(data)
            print("✅ Post created")
            errorMessage = nil
            return true
        } catch {
            let msg = error.localizedDescription
            print("❌ Failed to create post:", msg)
            errorMessage = msg
            return false
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
        _ = try requireAuthUser(matchingExpectedUid: userId)
        try await runWrite(successLog: "Reaction updated") {
            try await self.performApplyReaction(postId: postId, userId: userId, emoji: emoji)
        }
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
        try await runWrite(successLog: "Recommendation feedback saved") {
            let ref = self.db.collection("users").document(userId).collection("recommendationFeedback").document()
            try await ref.setData([
                "recommendationId": recommendationId,
                "helpful": helpful,
                "createdAt": FieldValue.serverTimestamp()
            ])
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
        try await runWrite(successLog: "Recommendation feedback saved") {
            let ref = self.db.collection("users").document(userId).collection("recommendationFeedback").document()
            try await ref.setData([
                "recommendationId": recommendationId,
                "title": title,
                "reason": reason,
                "type": type.rawValue,
                "helpful": helpful,
                "createdAt": FieldValue.serverTimestamp()
            ])
        }
    }
}
