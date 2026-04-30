import Foundation
import SwiftUI
import FirebaseFirestore

/// FILE: Models/FeedModels.swift
/// UI feed models + mapping from Firestore documents.

enum PostVisibility: String, CaseIterable, Codable, Hashable {
    case `public` = "Public"
    case friends = "Friends"
    case `private` = "Private"
    /// Visible to members of `sharedGroupIds` on the post (see `SocialGroup`).
    case groups = "Groups"
}

struct FeedUser: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var isFollowing: Bool
    var streak: Int

    init(id: String, name: String, isFollowing: Bool = false, streak: Int = 0) {
        self.id = id
        self.name = name
        self.isFollowing = isFollowing
        self.streak = streak
    }
}

struct FeedPost: Identifiable, Equatable, Hashable {
    let id: String
    let authorId: String
    var user: FeedUser
    var emoji: String
    var insight: String
    var whoop: String
    var goal: String
    /// Calendar week number stored at post time (fallback derived from `createdAt` for older posts).
    var wrapupWeekNumber: Int
    /// Emotion tags from the wrapup check-in (empty for older posts).
    var selectedEmotions: [String]
    var likeCount: Int
    var likedBy: [String]
    var reactions: [String: Int]
    var userReactions: [String: String]
    /// Legacy inline comments (older posts). Prefer `commentCount` for display.
    var comments: [String]
    /// Denormalized count; kept in sync when adding subcollection comments.
    var commentCount: Int
    var visibility: PostVisibility
    /// Optional 1–10 self-rated intensity (newer posts).
    var intensity: Int?
    var whatHelped: String?
    /// Multi-select “what helped” tags from check-in (newer posts).
    var helpfulTags: [String]
    /// When `visibility == .groups`, these are `SocialGroup.id` values that may see the post.
    var sharedGroupIds: [String]
    var createdAt: Date?

    /// First saved emotion label (Firestore array order) for reactions and calendar tinting.
    var primaryEmotion: String {
        (selectedEmotions.first ?? "").lowercased()
    }

    /// Non-empty first emotion for UI chips (preserves casing from the post).
    var primaryEmotionDisplayLabel: String {
        let raw = selectedEmotions.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw
    }

    func isLikedByCurrentUser(_ uid: String?) -> Bool {
        guard let uid else { return false }
        return likedBy.contains(uid)
    }

    func reactionForCurrentUser(_ uid: String?) -> String? {
        guard let uid else { return nil }
        return userReactions[uid]
    }

    /// Mock / preview data (not decoded from Firestore).
    init(
        id: String,
        authorId: String,
        user: FeedUser,
        emoji: String,
        insight: String,
        whoop: String,
        goal: String,
        wrapupWeekNumber: Int = Calendar.current.component(.weekOfYear, from: Date()),
        selectedEmotions: [String] = [],
        likeCount: Int = 0,
        likedBy: [String] = [],
        reactions: [String: Int]? = nil,
        userReactions: [String: String] = [:],
        comments: [String] = [],
        commentCount: Int? = nil,
        visibility: PostVisibility = .public,
        intensity: Int? = nil,
        whatHelped: String? = nil,
        helpfulTags: [String] = [],
        sharedGroupIds: [String] = [],
        createdAt: Date? = Date()
    ) {
        self.id = id
        self.authorId = authorId
        self.user = user
        self.emoji = emoji
        self.insight = insight
        self.whoop = whoop
        self.goal = goal
        self.wrapupWeekNumber = wrapupWeekNumber
        self.selectedEmotions = selectedEmotions
        self.likeCount = likeCount
        self.likedBy = likedBy
        self.reactions = reactions ?? FirestoreFieldParsing.defaultReactions()
        self.userReactions = userReactions
        self.comments = comments
        self.commentCount = commentCount ?? max(comments.count, 0)
        self.visibility = visibility
        self.intensity = intensity
        self.whatHelped = whatHelped
        self.helpfulTags = helpfulTags
        self.sharedGroupIds = sharedGroupIds
        self.createdAt = createdAt
    }
}

private enum FirestoreFieldParsing {
    static func intValue(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let l = any as? Int64 { return Int(l) }
        if let d = any as? Double { return Int(d) }
        return 0
    }

    static func defaultReactions() -> [String: Int] {
        FeedReactions.defaultCounts
    }
}

extension FeedPost {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        let resolvedAuthorId = (data["authorId"] as? String) ?? (data["userId"] as? String)
        guard let userId = resolvedAuthorId,
              let userName = data["userName"] as? String else { return nil }

        let emoji = data["weeklyEmoji"] as? String ?? "✨"
        let insight = data["emotionalInsight"] as? String ?? ""
        let whoop = data["whoopsText"] as? String ?? ""
        let goal = data["weeklyGoal"] as? String ?? ""
        let likeCount = FirestoreFieldParsing.intValue(data["likeCount"])
        let likedBy = data["likedBy"] as? [String] ?? []
        let userReactionsDirect = data["userReactions"] as? [String: String] ?? [:]
        let reactionUsersAlias = data["reactionUsers"] as? [String: String] ?? [:]
        let userReactions = userReactionsDirect.merging(reactionUsersAlias) { existing, _ in existing }
        let legacyComments = data["comments"] as? [String] ?? []
        let visString = data["visibility"] as? String ?? PostVisibility.public.rawValue
        let visibility = PostVisibility(rawValue: visString) ?? .public

        var reactions = FirestoreFieldParsing.defaultReactions()
        if let raw = data["reactions"] as? [String: Any] {
            for (k, v) in raw {
                reactions[k] = FirestoreFieldParsing.intValue(v)
            }
        }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        let storedCount = FirestoreFieldParsing.intValue(data["commentCount"])
        let commentCount = max(storedCount, legacyComments.count)

        let storedWeek = FirestoreFieldParsing.intValue(data["weekNumber"])
        let emotionTags = data["selectedEmotions"] as? [String] ?? []
        let resolvedWeek: Int = {
            if storedWeek > 0 { return storedWeek }
            if let d = createdAt {
                return Calendar.current.component(.weekOfYear, from: d)
            }
            return Calendar.current.component(.weekOfYear, from: Date())
        }()

        self.id = document.documentID
        self.authorId = userId
        self.user = FeedUser(id: userId, name: userName, isFollowing: false, streak: 0)
        self.emoji = emoji
        self.insight = insight
        self.whoop = whoop
        self.goal = goal
        self.wrapupWeekNumber = resolvedWeek
        self.selectedEmotions = emotionTags
        self.likeCount = likeCount
        self.likedBy = likedBy
        self.reactions = reactions
        self.userReactions = userReactions
        self.comments = legacyComments
        self.commentCount = commentCount
        self.visibility = visibility

        let intensityDecoded: Int? = {
            if let i = data["intensity"] as? Int { return i }
            if let l = data["intensity"] as? Int64 { return Int(l) }
            if let d = data["intensity"] as? Double { return Int(d) }
            return nil
        }()
        self.intensity = intensityDecoded
        let tipRaw = (data["helpfulText"] as? String) ?? (data["whatHelped"] as? String)
        let trimmedTip = tipRaw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.whatHelped = trimmedTip.isEmpty ? nil : trimmedTip
        self.helpfulTags = data["helpfulTags"] as? [String] ?? []
        self.sharedGroupIds = data["sharedGroupIds"] as? [String] ?? []
        self.createdAt = createdAt
    }
}
