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
    /// User-visible Firestore / auth errors (optional alert in views).
    @Published var errorMessage: String?

    /// Lazily created so Xcode Previews never touch Firestore unless a Firebase-backed method runs.
    private lazy var db: Firestore = Firestore.firestore()
    private var postsListener: ListenerRegistration?
    private var commentsListener: ListenerRegistration?
    private var followingListener: ListenerRegistration?

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
        followingIds = []
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
                    self.posts = mapped
                }
            }
    }

    func stopPostsListener() {
        postsListener?.remove()
        postsListener = nil
        posts = []
    }

    #if DEBUG
    /// Seed the feed for SwiftUI Previews without starting a Firestore listener.
    func applyPreviewPosts(_ newPosts: [FeedPost]) {
        postsListener?.remove()
        postsListener = nil
        posts = newPosts
    }

    func applyPreviewComments(_ list: [Comment]) {
        commentsListener?.remove()
        commentsListener = nil
        detailComments = list
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
                let mapped = documents.compactMap { Comment(document: $0) }
                Task { @MainActor in
                    self.detailComments = mapped
                }
            }
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
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: commentRef)
            batch.updateData(["commentCount": FieldValue.increment(Int64(1))], forDocument: postRef)
            try await batch.commit()
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

    func setFollowing(currentUserId: String, targetUserId: String, follow: Bool) async throws {
        guard currentUserId != targetUserId else { return }
        _ = try requireAuthUser(matchingExpectedUid: currentUserId)
        try await runWrite(successLog: follow ? "Now following user" : "Unfollowed user") {
            let ref = self.db.collection("users").document(currentUserId)
            if follow {
                try await ref.updateData(["following": FieldValue.arrayUnion([targetUserId])])
            } else {
                try await ref.updateData(["following": FieldValue.arrayRemove([targetUserId])])
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

        let goalLine: String = weekly.isEmpty ? monthly : weekly
        let displayEmoji = emoji.isEmpty ? "✨" : emoji

        let data: [String: Any] = [
            "userId": authorId,
            "userName": trimmedName,
            "weeklyEmoji": displayEmoji,
            "emotionalInsight": insight,
            "whoopsText": whoops,
            "weeklyGoal": goalLine,
            "createdAt": FieldValue.serverTimestamp(),
            "likeCount": 0,
            "likedBy": [] as [String],
            "reactions": reactionsPayload,
            "userReactions": [:] as [String: String],
            "visibility": checkIn.visibility.rawValue,
            "commentCount": 0
        ]

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
                    var userReactions = data["userReactions"] as? [String: String] ?? [:]
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
                        "userReactions": userReactions
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

    // MARK: - Helpers (shared with FeedPost mapping)

    static func defaultReactionCounts() -> [String: Int] {
        ["❤️": 0, "🔥": 0, "😮": 0]
    }

    static func intFromFirestore(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let l = any as? Int64 { return Int(l) }
        if let d = any as? Double { return Int(d) }
        return 0
    }

    static func normalizeReactions(_ dict: [String: Any]?) -> [String: Int] {
        guard let dict else { return defaultReactionCounts() }
        var out: [String: Int] = [:]
        for (k, v) in dict {
            out[k] = intFromFirestore(v)
        }
        for k in ["❤️", "🔥", "😮"] where out[k] == nil {
            out[k] = 0
        }
        return out
    }
}
