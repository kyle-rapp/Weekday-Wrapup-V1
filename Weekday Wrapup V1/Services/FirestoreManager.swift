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
    @Published private(set) var blockedUserIds: Set<String> = []
    /// Group ids the current user belongs to (for `PostVisibility.groups` feed filtering).
    @Published private(set) var joinedGroupIds: Set<String> = []
    @Published private(set) var myGroups: [SocialGroup] = []
    @Published private(set) var discoverableGroups: [SocialGroup] = []
    @Published private(set) var isDiscoverableGroupsLoading: Bool = false
    @Published private(set) var discoverableGroupsVersion: Int = 0
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
    private var blockedUsersListener: ListenerRegistration?
    private var groupsListener: ListenerRegistration?
    private var activeCommentsPostId: String?
    private var activeFollowingUserId: String?
    private var activeBlockedUsersUserId: String?
    private var activeGroupsUserId: String?
    private var lastDiscoverableLoadUserId: String?
    private var lastPublishedErrorMessage: String?
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
            let technicalMessage = error.localizedDescription
            AppLogger.error("[FIRESTORE] Write failed: \(technicalMessage)")
            publishUserFacingError(from: error)
            throw error
        }
    }

    private func reportListenerError(_ context: String, error: Error) {
        AppLogger.error("\(context): \(error.localizedDescription)")
        publishUserFacingError(from: error)
    }

    private func publishUserFacingError(from error: Error) {
        let message = userFacingErrorMessage(from: error)
        guard message != lastPublishedErrorMessage else { return }
        lastPublishedErrorMessage = message
        errorMessage = message
    }

    private func userFacingErrorMessage(from error: Error) -> String {
        let technical = error.localizedDescription.lowercased()
        if technical.contains("insufficient permissions") || technical.contains("permission") {
            return "We couldn't load this section right now."
        }
        if technical.contains("network") || technical.contains("offline") || technical.contains("timed out") {
            return "You're offline or the connection is slow. Please try again in a moment."
        }
        if technical.contains("unauth") || technical.contains("sign in") {
            return "Please sign in again to continue."
        }
        return "Something went wrong. Please try again."
    }

    // MARK: - Session teardown

    func teardownForLogout() {
        stopPostsListener()
        stopCommentsListener()
        stopFollowingListener()
        stopBlockedUsersListener()
        stopGroupsListener()
        followingIds = []
        blockedUserIds = []
        joinedGroupIds = []
        myGroups = []
        discoverableGroups = []
        profileCacheUserId = nil
        cachedHelpfulProfile = [:]
        cachedSimilarUserIds = []
        activeNudge = nil
        isDiscoverableGroupsLoading = false
        discoverableGroupsVersion = 0
        lastDiscoverableLoadUserId = nil
        errorMessage = nil
        lastPublishedErrorMessage = nil
    }

    // MARK: - Posts listener

    func startPostsListener() {
        if isUITestMode {
            if posts.isEmpty {
                applyPreviewPosts(SeedDataManager.previewSeedPosts())
            }
            return
        }
        guard postsListener == nil else { return }
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
        let visible = allPostsRaw.filter {
            !blockedUserIds.contains($0.authorId)
                && Self.postMeetsVisibility($0, viewerId: uid, joinedGroupIds: joinedGroupIds)
        }
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
            discoverableGroups = []
            return
        }
        #if DEBUG
        if Self.isXcodePreview { return }
        #endif
        if activeGroupsUserId == userId, groupsListener != nil {
            return
        }
        stopGroupsListener()
        activeGroupsUserId = userId
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
                    self.socialGroup(from: doc)
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
        activeGroupsUserId = nil
        joinedGroupIds = []
        myGroups = []
        discoverableGroups = []
    }

    func loadDiscoverableGroups(forceRefresh: Bool = false, limit: Int = 240) async {
        if isUITestMode {
            await MainActor.run {
                discoverableGroups = []
                isDiscoverableGroupsLoading = false
            }
            return
        }
        #if DEBUG
        if Self.isXcodePreview { return }
        #endif
        let currentUid = Auth.auth().currentUser?.uid ?? "_none"
        if !forceRefresh,
           !discoverableGroups.isEmpty,
           lastDiscoverableLoadUserId == currentUid {
            return
        }
        if isDiscoverableGroupsLoading {
            return
        }
        isDiscoverableGroupsLoading = true
        defer { isDiscoverableGroupsLoading = false }

        // Canonical pipeline: ensure defaults exist before merge/fetch.
        await seedDefaultGroupsIfNeeded()

        do {
            let liveGroups: [SocialGroup]
            let liveDocs: [QueryDocumentSnapshot]
            do {
                let snap = try await db.collection("groups")
                    .order(by: "createdAt", descending: true)
                    .limit(to: limit)
                    .getDocuments()
                liveDocs = snap.documents
                liveGroups = snap.documents.compactMap { socialGroup(from: $0) }
            } catch {
                AppLogger.error("loadDiscoverableGroups groups query failed: \(error.localizedDescription)")
                liveDocs = []
                liveGroups = []
            }

            let defaultGroups: [SocialGroup]
            let defaultDocs: [QueryDocumentSnapshot]
            do {
                let defaultsSnap = try await db.collection("default_groups")
                    .getDocuments()
                defaultDocs = defaultsSnap.documents
                defaultGroups = defaultsSnap.documents.compactMap { defaultGroupStub(from: $0) }
            } catch {
                AppLogger.error("loadDiscoverableGroups default_groups query failed: \(error.localizedDescription)")
                defaultDocs = []
                defaultGroups = []
            }
            let localDefaultGroups: [SocialGroup] = DefaultGroups.all.map { name in
                let description = "Peer support for \(name.lowercased()) with emotionally safe, low-pressure check-ins."
                return SocialGroup(
                    id: "default_local_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))",
                    name: name,
                    memberIds: [],
                    createdBy: "seed-default-group",
                    adminIds: ["seed-default-group"],
                    createdAt: nil,
                    invitedContacts: nil,
                    allowHistoryAccessForNewMembers: nil,
                    memberHistoryAccess: nil,
                    description: description,
                    tags: DefaultGroups.tagsForGroup(name: name, description: description),
                    searchKeywords: DefaultGroups.searchKeywordsForGroup(name: name, description: description),
                    category: DefaultGroups.categoryForGroup(named: name)
                )
            }
            var mergedByName: [String: SocialGroup] = [:]
            for group in liveGroups {
                mergedByName[group.name.lowercased()] = group
            }
            for stub in defaultGroups {
                let key = stub.name.lowercased()
                if var existing = mergedByName[key] {
                    if existing.description?.isEmpty ?? true { existing.description = stub.description }
                    if existing.category?.isEmpty ?? true { existing.category = stub.category }
                    if existing.tags.isEmpty { existing.tags = stub.tags }
                    if existing.searchKeywords.isEmpty { existing.searchKeywords = stub.searchKeywords }
                    mergedByName[key] = existing
                } else {
                    mergedByName[key] = stub
                }
            }
            for local in localDefaultGroups {
                let key = local.name.lowercased()
                if mergedByName[key] == nil {
                    mergedByName[key] = local
                }
            }
            let groups = Array(mergedByName.values)
            #if DEBUG
            let staticNames = DefaultGroups.all
            let staticFirst = staticNames.prefix(50).joined(separator: " | ")
            print("[GROUP_SEARCH] DEFAULT_GROUP_STATIC_COUNT=\(staticNames.count)")
            print("[GROUP_SEARCH] DEFAULT_GROUP_STATIC_NAMES=\(staticFirst)")
            print("[GROUP_SEARCH] DEFAULT_GROUPS_COLLECTION_COUNT=\(defaultGroups.count)")
            print("[GROUP_SEARCH] DEFAULT_GROUPS_COLLECTION_NAMES=\(defaultGroups.map(\.name).sorted().prefix(50).joined(separator: " | "))")
            print("[GROUP_SEARCH] DEFAULT_GROUPS_LOCAL_FALLBACK_COUNT=\(localDefaultGroups.count)")
            print("[GROUP_SEARCH] LIVE_GROUPS_COLLECTION_COUNT=\(liveGroups.count)")
            print("[GROUP_SEARCH] MERGED_DISCOVERABLE_GROUPS_COUNT=\(groups.count)")
            print("[GROUP_SEARCH] MERGED_DISCOVERABLE_GROUPS_NAMES=\(groups.map(\.name).sorted().prefix(50).joined(separator: " | "))")
            print("[GROUP_SEARCH] collections=groups+default_groups live=\(liveGroups.count) defaults=\(defaultGroups.count) merged=\(groups.count)")
            let firstTwenty = groups
                .map(\.name)
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .prefix(20)
                .joined(separator: " | ")
            print("[GROUP_SEARCH] merged_first_20=\(firstTwenty)")
            let mergedNames = groups.map { $0.name.lowercased() }
            let hasBurnout = mergedNames.contains { $0.contains("burnout") }
            let hasPTSD = mergedNames.contains { $0 == "ptsd" || $0.contains("post traumatic stress") || $0.contains("post-traumatic stress") }
            let staticLower = staticNames.map { $0.lowercased() }
            let defaultLower = defaultGroups.map { $0.name.lowercased() }
            print("[GROUP_SEARCH] HAS_STATIC_BURNOUT=\(staticLower.contains { $0.contains("burnout") })")
            print("[GROUP_SEARCH] HAS_STATIC_PTSD=\(staticLower.contains { $0 == "ptsd" || $0.contains("post traumatic stress") || $0.contains("post-traumatic stress") })")
            print("[GROUP_SEARCH] HAS_FIRESTORE_BURNOUT=\(defaultLower.contains { $0.contains("burnout") })")
            print("[GROUP_SEARCH] HAS_FIRESTORE_PTSD=\(defaultLower.contains { $0 == "ptsd" || $0.contains("post traumatic stress") || $0.contains("post-traumatic stress") })")
            print("[GROUP_SEARCH] HAS_MERGED_BURNOUT=\(hasBurnout)")
            print("[GROUP_SEARCH] HAS_MERGED_PTSD=\(hasPTSD)")
            print("[GROUP_SEARCH] merged_has_burnout=\(hasBurnout) merged_has_ptsd=\(hasPTSD)")
            print("[GROUP_SEARCH] validation burnout_present=\(hasBurnout) ptsd_present=\(hasPTSD) groups_count=\(liveGroups.count) default_groups_count=\(defaultGroups.count) merged_count=\(groups.count)")
            debugLogRelevantGroupDocuments(liveDocs, source: "groups")
            debugLogRelevantGroupDocuments(defaultDocs, source: "default_groups")
            #endif
            await MainActor.run {
                self.discoverableGroups = groups.sorted { lhs, rhs in
                    if lhs.memberIds.count != rhs.memberIds.count {
                        return lhs.memberIds.count > rhs.memberIds.count
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                self.lastDiscoverableLoadUserId = currentUid
                self.discoverableGroupsVersion += 1
            }
        } catch {
            AppLogger.error("loadDiscoverableGroups failed: \(error.localizedDescription)")
            await MainActor.run {
                self.discoverableGroups = []
                self.discoverableGroupsVersion += 1
            }
        }
    }

    #if DEBUG
    private func debugLogRelevantGroupDocuments(_ docs: [QueryDocumentSnapshot], source: String) {
        let keywords = ["burnout", "ptsd", "post traumatic stress", "post-traumatic stress", "trauma"]
        for doc in docs {
            let data = doc.data()
            let name = (data["name"] as? String) ?? ""
            let description = (data["description"] as? String) ?? ""
            let category = (data["category"] as? String) ?? ""
            let tags = (data["tags"] as? [String]) ?? []
            let searchKeywords = (data["searchKeywords"] as? [String]) ?? []
            let blob = "\(name) \(description) \(category) \(tags.joined(separator: " ")) \(searchKeywords.joined(separator: " "))".lowercased()
            guard keywords.contains(where: { blob.contains($0) }) else { continue }
            print("[GROUP_SEARCH][MODEL] source=\(source) id=\(doc.documentID) name='\(name)' category='\(category)' description='\(description)' tags=\(tags) searchKeywords=\(searchKeywords)")
        }
    }
    #endif

    /// Creates a `groups` document. Writes `ownerId` and legacy `createdBy` (same uid) for compatibility.
    func createGroup(
        name: String,
        description: String? = nil,
        tags: [String] = [],
        category: String? = nil,
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
        let resolvedCategory = (category?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? category!.trimmingCharacters(in: .whitespacesAndNewlines)
            : DefaultGroups.categoryForGroup(named: trimmed)
        let resolvedTags = {
            let explicit = tags
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            let inferred = DefaultGroups.tagsForGroup(name: trimmed, description: trimmedDescription)
            var seen = Set<String>()
            return (explicit + inferred).filter { seen.insert($0).inserted }
        }()
        let resolvedSearchKeywords = DefaultGroups.searchKeywordsForGroup(name: trimmed, description: trimmedDescription)
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
            payload["category"] = resolvedCategory
            payload["tags"] = resolvedTags
            payload["searchKeywords"] = resolvedSearchKeywords
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

    /// Lets a user join a suggested/default community by name.
    /// Reuses an existing group when found, otherwise creates one.
    func joinSuggestedGroup(named groupName: String, userId: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let existing = try await db.collection("groups")
            .whereField("name", isEqualTo: trimmedName)
            .limit(to: 1)
            .getDocuments()

        if let doc = existing.documents.first {
            let description = (doc.data()["description"] as? String) ?? "Low-pressure support community"
            try await doc.reference.updateData([
                "memberIds": FieldValue.arrayUnion([userId]),
                "category": DefaultGroups.categoryForGroup(named: trimmedName),
                "tags": DefaultGroups.tagsForGroup(name: trimmedName, description: description),
                "searchKeywords": DefaultGroups.searchKeywordsForGroup(name: trimmedName, description: description)
            ])
            return
        }

        try await createGroup(
            name: trimmedName,
            description: "Low-pressure support community",
            tags: DefaultGroups.tagsForGroup(name: trimmedName, description: "Low-pressure support community"),
            category: DefaultGroups.categoryForGroup(named: trimmedName),
            memberIds: [userId],
            ownerId: userId,
            allowHistoryAccessForNewMembers: false
        )
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
        if activeCommentsPostId == postId, commentsListener != nil {
            return
        }
        stopCommentsListener()
        activeCommentsPostId = postId
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
        activeCommentsPostId = nil
        detailComments = []
    }

    // MARK: - Blocking

    func startBlockedUsersListener(userId: String) {
        let authUid = Auth.auth().currentUser?.uid
        #if DEBUG
        print("[FIRESTORE][blockedUsers] authUid=\(authUid ?? "nil") requestedUid=\(userId) path=users/\(userId)/blockedUsers matchesAuth=\(authUid == userId)")
        #endif
        guard authUid == userId else {
            #if DEBUG
            print("[FIRESTORE][blockedUsers] listener skipped until Firebase Auth UID matches requested UID")
            #endif
            return
        }
        if activeBlockedUsersUserId == userId, blockedUsersListener != nil { return }
        stopBlockedUsersListener()
        activeBlockedUsersUserId = userId
        blockedUsersListener = db.collection("users").document(userId).collection("blockedUsers")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    Task { @MainActor in self.reportListenerError("Blocked users listener", error: error) }
                    return
                }
                let ids = Set(snapshot?.documents.map(\.documentID) ?? [])
                Task { @MainActor in
                    self.blockedUserIds = ids
                    self.applyPostVisibilityFilter()
                }
            }
    }

    func stopBlockedUsersListener() {
        blockedUsersListener?.remove()
        blockedUsersListener = nil
        activeBlockedUsersUserId = nil
        blockedUserIds = []
    }

    func blockUser(currentUserId: String, blockedUserId: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: currentUserId)
        guard currentUserId != blockedUserId else { return }
        try await runWrite(successLog: "User blocked") {
            try await self.db.collection("users")
                .document(currentUserId)
                .collection("blockedUsers")
                .document(blockedUserId)
                .setData([
                    "blockedUserId": blockedUserId,
                    "createdAt": FieldValue.serverTimestamp()
                ], merge: true)
        }
        blockedUserIds.insert(blockedUserId)
        applyPostVisibilityFilter()
    }

    private func interactionBlockedBetween(actorId: String, otherUserId: String) async -> Bool {
        guard actorId != otherUserId else { return false }
        do {
            async let actorBlockedOther = db.collection("users").document(actorId).collection("blockedUsers").document(otherUserId).getDocument()
            async let otherBlockedActor = db.collection("users").document(otherUserId).collection("blockedUsers").document(actorId).getDocument()
            let actorSnap = try await actorBlockedOther
            let otherSnap = try await otherBlockedActor
            return actorSnap.exists || otherSnap.exists
        } catch {
            AppLogger.error("interactionBlockedBetween failed: \(error.localizedDescription)")
            return false
        }
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
        let postRef = db.collection("posts").document(postId)
        let postSnap = try await postRef.getDocument()
        let postData = postSnap.data() ?? [:]
        if let authorId = (postData["authorId"] as? String) ?? (postData["userId"] as? String),
           await interactionBlockedBetween(actorId: userId, otherUserId: authorId) {
            let err = NSError(domain: "FirestoreManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can't comment on this post."])
            errorMessage = err.localizedDescription
            throw err
        }
        if postData["hideComments"] as? Bool == true {
            let err = NSError(domain: "FirestoreManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Comments are disabled for this post"])
            errorMessage = err.localizedDescription
            throw err
        }
        try await runWrite(successLog: "Comment added") {
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
        let postRef = db.collection("posts").document(postId)
        let postSnap = try await postRef.getDocument()
        let postData = postSnap.data() ?? [:]
        if let authorId = (postData["authorId"] as? String) ?? (postData["userId"] as? String),
           await interactionBlockedBetween(actorId: userId, otherUserId: authorId) {
            let err = NSError(domain: "FirestoreManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can't reply to this post."])
            errorMessage = err.localizedDescription
            throw err
        }
        if postData["hideComments"] as? Bool == true {
            let err = NSError(domain: "FirestoreManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Comments are disabled for this post"])
            errorMessage = err.localizedDescription
            throw err
        }
        try await runWrite(successLog: "Reply added") {
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
        if activeFollowingUserId == userId, followingListener != nil {
            return
        }
        stopFollowingListener()
        activeFollowingUserId = userId
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
        activeFollowingUserId = nil
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

    /// Compatibility alias for older call sites.
    func getFollowerCount(userId: String) async -> Int {
        await fetchFollowerCount(userId: userId)
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

    /// Compatibility alias for older call sites.
    func getFollowingCount(userId: String) async -> Int {
        await fetchFollowingCount(userId: userId)
    }

    /// Number of mutual relationships for this user (`followers ∩ following`).
    func getFriendCount(userId: String) async -> Int {
        if Self.isXcodePreview { return 0 }
        do {
            async let followersTask = followersCollection(userId: userId).limit(to: 500).getDocuments()
            async let followingTask = followingCollection(userId: userId).limit(to: 500).getDocuments()
            let followerIds = Set(try await followersTask.documents.map(\.documentID))
            let followingIds = Set(try await followingTask.documents.map(\.documentID))
            return followerIds.intersection(followingIds).count
        } catch {
            AppLogger.error("getFriendCount failed: \(error.localizedDescription)")
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

            let allUsers = try await queryUsers.documents
            let followingSet = Set(try await myFollowingDocs.documents.map(\.documentID))

            var candidates: [(AppUser, Double)] = []
            for doc in allUsers {
                guard doc.documentID != user.id else { continue }
                guard !followingSet.contains(doc.documentID) else { continue }
                guard let appUser = appUserFromDocument(id: doc.documentID, data: doc.data()) else { continue }

                async let theirFollowerCount = fetchFollowerCount(userId: appUser.id)
                async let theirFollowingDocs = followingCollection(userId: appUser.id).limit(to: 120).getDocuments()

                let theirFollowingSet = Set((try await theirFollowingDocs).documents.map(\.documentID))

                // Other users' private insights are intentionally not read here; Firestore rules keep
                // `users/{uid}/insights/*` owner-only to avoid leaking emotional profile data.
                let emotionOverlap = 0.0
                let sharedHelpfulTags = 0.0
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
        let gratitude = checkIn.gratitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lookForward = checkIn.lookForwardTo.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasContent = !emoji.isEmpty || !insight.isEmpty || !whoops.isEmpty
            || !weekly.isEmpty || !monthly.isEmpty || !gratitude.isEmpty || !lookForward.isEmpty
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

        let goalLine: String = {
            if !lookForward.isEmpty { return lookForward }
            if !weekly.isEmpty { return weekly }
            return monthly
        }()
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
            "lookForwardTo": goalLine,
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
            "softSupportByUser": [:] as [String: [String]],
            "hideReactions": checkIn.hideReactions,
            "hideComments": checkIn.hideComments
        ]
        if !gratitude.isEmpty {
            data["gratitudeText"] = gratitude
        }
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
        let lookForward = checkIn.lookForwardTo.trimmingCharacters(in: .whitespacesAndNewlines)
        let goalLine: String = {
            if !lookForward.isEmpty { return lookForward }
            if !weekly.isEmpty { return weekly }
            return monthly
        }()
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
            gratitudeText: checkIn.gratitudeText,
            lookForwardTo: goalLine,
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
        let authUid = Auth.auth().currentUser?.uid
        #if DEBUG
        print("[FIRESTORE][insights/profile] authUid=\(authUid ?? "nil") requestedUid=\(userId) path=users/\(userId)/insights/profile matchesAuth=\(authUid == userId)")
        #endif
        guard authUid == userId else {
            #if DEBUG
            print("[FIRESTORE][insights/profile] read skipped because requested UID is not the signed-in Firebase Auth UID")
            #endif
            return [:]
        }
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
            if !error.localizedDescription.lowercased().contains("permission") {
                AppLogger.error("fetchUserHelpfulProfile failed: \(error.localizedDescription)")
            }
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

    private func eventStreamRef(userId: String) -> CollectionReference {
        db.collection("users")
            .document(userId)
            .collection("eventStream")
    }

    private func adaptiveProfileRef(userId: String) -> DocumentReference {
        db.collection("users")
            .document(userId)
            .collection("adaptiveProfile")
            .document("main")
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

    func saveEmotionalEvent(userId: String, event: EmotionalEvent) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        do {
            try await self.eventStreamRef(userId: userId).document(event.eventId).setData(event.asFirestoreDictionary(), merge: true)
            AppLogger.log("[FIRESTORE] Emotional event saved")
        } catch {
            AppLogger.error("saveEmotionalEvent failed: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchAdaptiveProfile(userId: String) async -> UserAdaptiveProfile {
        if Self.isXcodePreview { return UserAdaptiveProfile() }
        do {
            let snap = try await adaptiveProfileRef(userId: userId).getDocument()
            guard snap.exists, let data = snap.data() else { return UserAdaptiveProfile() }
            return (try? UserAdaptiveProfile.fromFirestoreDictionary(data)) ?? UserAdaptiveProfile()
        } catch {
            AppLogger.error("fetchAdaptiveProfile failed: \(error.localizedDescription)")
            return UserAdaptiveProfile()
        }
    }

    func saveAdaptiveProfile(userId: String, profile: UserAdaptiveProfile) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        do {
            let payload = try profile.asFirestoreDictionary()
            try await self.adaptiveProfileRef(userId: userId).setData(payload, merge: true)
            AppLogger.log("[FIRESTORE] Adaptive profile saved")
        } catch {
            AppLogger.error("saveAdaptiveProfile failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Beta moderation signal — `reports/{reportId}`.
    func submitReport(
        reporterUserId: String,
        target: ReportTarget,
        reason: String,
        details: String?
    ) async throws {
        _ = try requireAuthUser(matchingExpectedUid: reporterUserId)
        try await runWrite(successLog: "Report submitted") {
            let ref = self.db.collection("reports").document()
            var payload: [String: Any] = [
                "reportId": ref.documentID,
                "reporterUserId": reporterUserId,
                "reason": reason,
                "createdAt": FieldValue.serverTimestamp(),
                "status": "open"
            ]
            if let reportedUserId = target.reportedUserId, !reportedUserId.isEmpty {
                payload["reportedUserId"] = reportedUserId
            }
            if let reportedPostId = target.reportedPostId, !reportedPostId.isEmpty {
                payload["reportedPostId"] = reportedPostId
            }
            if let reportedCommentId = target.reportedCommentId, !reportedCommentId.isEmpty {
                payload["reportedCommentId"] = reportedCommentId
            }
            let cleanDetails = details?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !cleanDetails.isEmpty {
                payload["details"] = cleanDetails
            }
            try await ref.setData(payload, merge: true)
        }
    }

    func submitUserReport(reporterId: String, reportedUserId: String, reason: String?) async throws {
        try await submitReport(
            reporterUserId: reporterId,
            target: ReportTarget(reportedUserId: reportedUserId),
            reason: reason ?? ReportReason.other.rawValue,
            details: nil
        )
    }

    func deleteOwnPost(postId: String, currentUserId: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: currentUserId)
        let ref = db.collection("posts").document(postId)
        let snap = try await ref.getDocument()
        let authorId = (snap.data()?["authorId"] as? String) ?? (snap.data()?["userId"] as? String)
        guard authorId == currentUserId else {
            throw NSError(domain: "FirestoreManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only delete your own posts."])
        }
        try await runWrite(successLog: "Post deleted") {
            try await ref.delete()
        }
        allPostsRaw.removeAll { $0.id == postId }
        applyPostVisibilityFilter()
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
            let rootSnap = try await userRootRef(userId: userId).getDocument()
            let profileSnap = try await userPublicProfileRef(userId: userId).getDocument()
            let root = rootSnap.data() ?? [:]
            let profile = profileSnap.data() ?? [:]

            var merged = profile
            if merged["name"] == nil {
                merged["name"] = root["name"] as? String
            }
            if merged["profileImageURL"] == nil {
                merged["profileImageURL"] = root["profileImageURL"] as? String
            }
            if merged["zodiacSign"] == nil {
                merged["zodiacSign"] = root["zodiacSign"] as? String
            }
            if merged["hasProfileImage"] == nil {
                merged["hasProfileImage"] = root["hasProfileImage"] as? Bool
            }

            guard !merged.isEmpty else { return nil }
            return try UserProfile.fromFirestoreDictionary(merged)
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

    /// Saves a positive check-in reflection for future recommendation tuning.
    /// Path: `users/{userId}/insights/positiveReflections/{autoId}`
    func savePositiveReflection(userId: String, emotion: String, text: String, tags: [String]) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let cleanedTags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        try await runWrite(successLog: "Positive reflection saved") {
            let ref = self.db.collection("users")
                .document(userId)
                .collection("insights")
                .document("positiveReflections")
                .collection("items")
                .document()
            try await ref.setData([
                "emotion": emotion,
                "text": trimmed,
                "tags": cleanedTags,
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }

    /// Top tags extracted from recent positive reflections.
    func fetchPositiveReflectionTags(userId: String, limit: Int = 40, topK: Int = 8) async -> [String] {
        if Self.isXcodePreview { return [] }
        do {
            let snap = try await db.collection("users")
                .document(userId)
                .collection("insights")
                .document("positiveReflections")
                .collection("items")
                .order(by: "createdAt", descending: true)
                .limit(to: max(1, limit))
                .getDocuments()

            var counts: [String: Int] = [:]
            for doc in snap.documents {
                let tags = doc.data()["tags"] as? [String] ?? []
                for tag in tags {
                    let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard !trimmed.isEmpty else { continue }
                    counts[trimmed, default: 0] += 1
                }
            }
            return counts
                .sorted {
                    if $0.value != $1.value { return $0.value > $1.value }
                    return $0.key < $1.key
                }
                .prefix(max(1, topK))
                .map(\.key)
        } catch {
            AppLogger.error("fetchPositiveReflectionTags failed: \(error.localizedDescription)")
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
                "zodiacSign": profile.zodiacSign ?? "",
                "profileImageURL": profile.profileImageURL ?? "",
                "hasProfileImage": profile.hasProfileImage ?? false,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            let profilePayload = try profile.asFirestoreDictionary()
            try await self.userPublicProfileRef(userId: userId).setData(profilePayload, merge: true)

            let detailsPayload = try details.asFirestoreDictionary()
            try await self.userProfileDetailsRef(userId: userId).setData(detailsPayload, merge: true)
        }
    }

    func saveOnboardingProfile(
        userId: String,
        displayName: String,
        zodiacSign: String,
        hasProfileImage: Bool
    ) async throws {
        _ = try requireAuthUser(matchingExpectedUid: userId)
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanZodiac = zodiacSign.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanZodiac.isEmpty else {
            throw NSError(domain: "FirestoreManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Name and zodiac are required"])
        }
        try await runWrite(successLog: "Onboarding profile saved") {
            try await self.userRootRef(userId: userId).setData([
                "name": cleanName,
                "zodiacSign": cleanZodiac,
                "hasProfileImage": hasProfileImage,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            let payload: [String: Any] = [
                "name": cleanName,
                "zodiacSign": cleanZodiac,
                "hasProfileImage": hasProfileImage
            ]
            try await self.userPublicProfileRef(userId: userId).setData(payload, merge: true)
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

    // MARK: - Thinking of You

    /// Sends a lightweight "thinking of you" poke. Enforces a 12-hour per-pair cooldown via UserDefaults.
    func sendThinkingOfYou(from fromId: String, to toId: String) async throws {
        let cooldownKey = "thinkingOfYou_\(fromId)_\(toId)"
        if let last = UserDefaults.standard.object(forKey: cooldownKey) as? Date,
           Date().timeIntervalSince(last) < 12 * 3600 {
            throw NSError(
                domain: "ThinkingOfYou",
                code: 429,
                userInfo: [NSLocalizedDescriptionKey: "You already reached out recently. Give them a little space. 🤍"]
            )
        }
        _ = try requireAuthUser(matchingExpectedUid: fromId)
        let ref = db.collection("thinking_of_you").document()
        try await ref.setData([
            "fromUserId": fromId,
            "toUserId": toId,
            "createdAt": FieldValue.serverTimestamp()
        ])
        UserDefaults.standard.set(Date(), forKey: cooldownKey)
        AppLogger.log("[THINKING_OF_YOU] Sent from \(fromId) to \(toId)")
    }

    func thinkingOfYouCooldownRemaining(from fromId: String, to toId: String) -> TimeInterval? {
        let key = "thinkingOfYou_\(fromId)_\(toId)"
        guard let last = UserDefaults.standard.object(forKey: key) as? Date else { return nil }
        let elapsed = Date().timeIntervalSince(last)
        let remaining = 12 * 3600 - elapsed
        return remaining > 0 ? remaining : nil
    }

    // MARK: - Direct Messaging

    /// Returns or creates a 1:1 conversation between two users.
    func fetchOrCreateConversation(between userA: String, and userB: String) async throws -> Conversation {
        let sorted = [userA, userB].sorted()
        let existing = try await db.collection("conversations")
            .whereField("participantIds", isEqualTo: sorted)
            .limit(to: 1)
            .getDocuments()
        if let doc = existing.documents.first, let conv = Conversation(document: doc, myUserId: userA) {
            return conv
        }
        let ref = db.collection("conversations").document()
        let data: [String: Any] = [
            "participantIds": sorted,
            "lastMessage": "",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await ref.setData(data)
        return Conversation(
            id: ref.documentID,
            participantIds: sorted,
            lastMessage: nil,
            updatedAt: Date()
        )
    }

    func fetchConversations(for userId: String) async -> [Conversation] {
        do {
            let snap = try await db.collection("conversations")
                .whereField("participantIds", arrayContains: userId)
                .order(by: "updatedAt", descending: true)
                .limit(to: 40)
                .getDocuments()
            return snap.documents.compactMap { Conversation(document: $0, myUserId: userId) }
        } catch {
            AppLogger.error("fetchConversations failed: \(error.localizedDescription)")
            return []
        }
    }

    func fetchMessages(conversationId: String) async -> [DirectMessage] {
        do {
            let snap = try await db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .order(by: "createdAt", descending: false)
                .limit(to: 100)
                .getDocuments()
            return snap.documents.compactMap { DirectMessage(document: $0, conversationId: conversationId) }
        } catch {
            AppLogger.error("fetchMessages failed: \(error.localizedDescription)")
            return []
        }
    }

    func sendDirectMessage(conversationId: String, senderId: String, text: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: senderId)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let msgRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document()
        try await msgRef.setData([
            "senderId": senderId,
            "text": trimmed,
            "createdAt": FieldValue.serverTimestamp()
        ])
        try await db.collection("conversations").document(conversationId).setData([
            "lastMessage": trimmed,
            "lastSenderId": senderId,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        AppLogger.log("[MSG] Sent in conversation \(conversationId)")
    }

    // MARK: - Default Groups Seeding

    /// Seeds the 100 default mental-health groups into Firestore (idempotent — skips existing names).
    func seedDefaultGroupsIfNeeded() async {
        guard Auth.auth().currentUser != nil else { return }
        do {
            let existingSnap = try await db.collection("default_groups").getDocuments()
            let existingNames = Set(existingSnap.documents.compactMap { ($0.data()["name"] as? String)?.lowercased() })
            let expectedNames = Set(DefaultGroups.all.map { $0.lowercased() })
            let missing = expectedNames.subtracting(existingNames)
            if missing.isEmpty {
                #if DEBUG
                print("[GROUP_SEARCH] seedDefaultGroupsIfNeeded complete existing=\(existingNames.count) missing=0")
                #endif
                return
            }

            let batch = db.batch()
            for name in DefaultGroups.all where missing.contains(name.lowercased()) {
                let ref = db.collection("default_groups").document(name.lowercased().replacingOccurrences(of: " ", with: "_"))
                let category = DefaultGroups.categoryForGroup(named: name)
                let description = "Peer support for \(name.lowercased()) with emotionally safe, low-pressure check-ins."
                let tags = DefaultGroups.tagsForGroup(name: name, description: description)
                let searchKeywords = DefaultGroups.searchKeywordsForGroup(name: name, description: description)
                batch.setData([
                    "name": name,
                    "description": description,
                    "category": category,
                    "tags": tags,
                    "searchKeywords": searchKeywords,
                    "isDefault": true,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ref, merge: true)
            }
            try await batch.commit()
            AppLogger.log("[SEED] Default groups seeded/updated missing=\(missing.count) expected=\(expectedNames.count) existing_before=\(existingNames.count)")
        } catch {
            AppLogger.error("seedDefaultGroupsIfNeeded failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Group Admin Voting

    /// Casts a vote for `candidateId` as admin in `groupId`. Each user can vote once.
    func voteForGroupAdmin(groupId: String, candidateId: String, voterId: String) async throws {
        _ = try requireAuthUser(matchingExpectedUid: voterId)
        let ref = db.collection("group_admin_votes").document(groupId)
        try await ref.setData([
            "candidates": FieldValue.arrayUnion([candidateId]),
            "votes_\(candidateId)": FieldValue.arrayUnion([voterId]),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        AppLogger.log("[VOTE] \(voterId) voted for \(candidateId) in group \(groupId)")
    }

    func fetchGroupAdminVotes(groupId: String) async -> [String: Int] {
        do {
            let snap = try await db.collection("group_admin_votes").document(groupId).getDocument()
            guard let data = snap.data() else { return [:] }
            let candidates = data["candidates"] as? [String] ?? []
            var result: [String: Int] = [:]
            for cid in candidates {
                let voters = data["votes_\(cid)"] as? [String] ?? []
                result[cid] = voters.count
            }
            return result
        } catch {
            AppLogger.error("fetchGroupAdminVotes failed: \(error.localizedDescription)")
            return [:]
        }
    }

    private func socialGroup(from doc: DocumentSnapshot) -> SocialGroup? {
        let data = doc.data() ?? [:]
        guard let name = data["name"] as? String else {
            #if DEBUG
            print("[GROUP_SEARCH][DECODE_FAIL] source=groups id=\(doc.documentID) missing=name fields=\(Array(data.keys))")
            #endif
            return nil
        }
        let memberIds = data["memberIds"] as? [String] ?? []
        let owner = (data["ownerId"] as? String) ?? (data["createdBy"] as? String) ?? "seed-default-group"
        let invited = data["invitedContacts"] as? [String]
        let allowHistory = data["allowHistoryAccessForNewMembers"] as? Bool
        let desc = data["description"] as? String
        let adminIds = data["adminIds"] as? [String]
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        let memberHistoryAccess = data["memberHistoryAccess"] as? [String: Bool]
        let category = (data["category"] as? String) ?? DefaultGroups.categoryForGroup(named: name)
        let tags = (data["tags"] as? [String]) ?? DefaultGroups.tagsForGroup(name: name, description: desc)
        let searchKeywords = (data["searchKeywords"] as? [String]) ?? DefaultGroups.searchKeywordsForGroup(name: name, description: desc)
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
            description: desc,
            tags: tags,
            searchKeywords: searchKeywords,
            category: category
        )
    }

    private func defaultGroupStub(from doc: DocumentSnapshot) -> SocialGroup? {
        let data = doc.data() ?? [:]
        guard let name = data["name"] as? String else {
            #if DEBUG
            print("[GROUP_SEARCH][DECODE_FAIL] source=default_groups id=\(doc.documentID) missing=name fields=\(Array(data.keys))")
            #endif
            return nil
        }
        let description = data["description"] as? String
        let category = (data["category"] as? String) ?? DefaultGroups.categoryForGroup(named: name)
        let tags = (data["tags"] as? [String]) ?? DefaultGroups.tagsForGroup(name: name, description: description)
        let searchKeywords = (data["searchKeywords"] as? [String]) ?? DefaultGroups.searchKeywordsForGroup(name: name, description: description)
        return SocialGroup(
            id: "default_\(doc.documentID)",
            name: name,
            memberIds: [],
            createdBy: "seed-default-group",
            adminIds: ["seed-default-group"],
            createdAt: nil,
            invitedContacts: nil,
            allowHistoryAccessForNewMembers: nil,
            memberHistoryAccess: nil,
            description: description,
            tags: tags,
            searchKeywords: searchKeywords,
            category: category
        )
    }
}

