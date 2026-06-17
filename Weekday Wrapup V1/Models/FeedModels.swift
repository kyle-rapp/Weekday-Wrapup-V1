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

enum FeedPostMediaType: String, Codable, Hashable {
    case image
    case video
    case none
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
    /// Gratitude captured during check-in (newer posts).
    var gratitudeText: String
    /// Anticipation / hope prompt (newer posts).
    var lookForwardTo: String
    var title: String?
    var imageURL: String?
    var mediaType: FeedPostMediaType
    var videoURL: String?
    var videoThumbnailURL: String?
    var videoDuration: Double?
    var videoWidth: Double?
    var videoHeight: Double?
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
    /// Optional semantic tags used by ranking (e.g. "milestone").
    var tags: [String]
    /// Manual calendar logging entry.
    var manualEntry: Bool
    /// When `visibility == .groups`, these are `SocialGroup.id` values that may see the post.
    var sharedGroupIds: [String]
    var createdAt: Date?
    /// Denormalized soft reactions (`posts/{id}/reactions` subcollection kept in sync).
    var softSupportCounts: [String: Int]
    /// `userId` → reaction type raw values this user has active on the post.
    var softSupportByUser: [String: [String]]
    /// Only the post author sees reaction counts; others can still react silently.
    var hideReactions: Bool
    /// Comment section hidden from all viewers.
    var hideComments: Bool
    /// Convenience semantic mirror for UI checks.
    var commentsEnabled: Bool { !hideComments }

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
        gratitudeText: String = "",
        lookForwardTo: String = "",
        title: String? = nil,
        imageURL: String? = nil,
        mediaType: FeedPostMediaType? = nil,
        videoURL: String? = nil,
        videoThumbnailURL: String? = nil,
        videoDuration: Double? = nil,
        videoWidth: Double? = nil,
        videoHeight: Double? = nil,
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
        tags: [String] = [],
        manualEntry: Bool = false,
        sharedGroupIds: [String] = [],
        createdAt: Date? = Date(),
        softSupportCounts: [String: Int]? = nil,
        softSupportByUser: [String: [String]]? = nil,
        hideReactions: Bool = false,
        hideComments: Bool = false
    ) {
        self.id = id
        self.authorId = authorId
        self.user = user
        self.emoji = emoji
        self.insight = insight
        self.whoop = whoop
        self.goal = goal
        self.gratitudeText = gratitudeText
        self.lookForwardTo = lookForwardTo
        self.title = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.imageURL = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanVideoURL = videoURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.videoURL = cleanVideoURL?.isEmpty == false ? cleanVideoURL : nil
        let cleanThumbURL = videoThumbnailURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.videoThumbnailURL = cleanThumbURL?.isEmpty == false ? cleanThumbURL : nil
        if let mediaType {
            self.mediaType = mediaType
        } else if self.videoURL != nil {
            self.mediaType = .video
        } else if self.imageURL?.isEmpty == false {
            self.mediaType = .image
        } else {
            self.mediaType = .none
        }
        self.videoDuration = videoDuration
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
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
        self.tags = tags
        self.manualEntry = manualEntry
        self.sharedGroupIds = sharedGroupIds
        self.createdAt = createdAt
        var counts = softSupportCounts ?? [:]
        for k in SoftSupportReactionKind.allCases.map(\.rawValue) where counts[k] == nil {
            counts[k] = 0
        }
        self.softSupportCounts = counts
        self.softSupportByUser = softSupportByUser ?? [:]
        self.hideReactions = hideReactions
        self.hideComments = hideComments
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
        let gratitudeText = data["gratitudeText"] as? String ?? ""
        let lookForwardRaw = data["lookForwardTo"] as? String ?? ""
        let lookForwardTo = lookForwardRaw.isEmpty ? goal : lookForwardRaw
        let titleRaw = data["title"] as? String
        let title = titleRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageURLRaw = data["imageURL"] as? String ?? ""
        let imageURL = imageURLRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let videoURLRaw = data["videoURL"] as? String ?? ""
        let videoURL = videoURLRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let videoThumbnailURLRaw = data["videoThumbnailURL"] as? String ?? ""
        let videoThumbnailURL = videoThumbnailURLRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedMediaType = FeedPostMediaType(rawValue: (data["mediaType"] as? String ?? "").lowercased())
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
        self.gratitudeText = gratitudeText
        self.lookForwardTo = lookForwardTo
        self.title = (title?.isEmpty == false) ? title : nil
        self.imageURL = imageURL.isEmpty ? nil : imageURL
        self.videoURL = videoURL.isEmpty ? nil : videoURL
        self.videoThumbnailURL = videoThumbnailURL.isEmpty ? nil : videoThumbnailURL
        if let storedMediaType {
            self.mediaType = storedMediaType
        } else if !videoURL.isEmpty {
            self.mediaType = .video
        } else if !imageURL.isEmpty {
            self.mediaType = .image
        } else {
            self.mediaType = .none
        }
        self.videoDuration = (data["videoDuration"] as? Double) ?? (data["videoDuration"] as? NSNumber)?.doubleValue
        self.videoWidth = (data["videoWidth"] as? Double) ?? (data["videoWidth"] as? NSNumber)?.doubleValue
        self.videoHeight = (data["videoHeight"] as? Double) ?? (data["videoHeight"] as? NSNumber)?.doubleValue
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
        self.tags = data["tags"] as? [String] ?? []
        self.manualEntry = data["manualEntry"] as? Bool ?? false
        self.sharedGroupIds = data["sharedGroupIds"] as? [String] ?? []
        self.createdAt = createdAt

        var softCounts: [String: Int] = [:]
        if let raw = data["softSupportCounts"] as? [String: Any] {
            for (k, v) in raw {
                softCounts[k] = FirestoreFieldParsing.intValue(v)
            }
        }
        for k in SoftSupportReactionKind.allCases.map(\.rawValue) where softCounts[k] == nil {
            softCounts[k] = 0
        }
        self.softSupportCounts = softCounts

        var byUser: [String: [String]] = [:]
        if let raw = data["softSupportByUser"] as? [String: Any] {
            for (uid, val) in raw {
                if let arr = val as? [String] {
                    byUser[uid] = arr
                }
            }
        }
        self.softSupportByUser = byUser
        self.hideReactions = data["hideReactions"] as? Bool ?? false
        self.hideComments = data["hideComments"] as? Bool ?? false
    }

    func softSupportCount(_ kind: SoftSupportReactionKind) -> Int {
        softSupportCounts[kind.rawValue] ?? 0
    }

    func softSupportSelected(_ kind: SoftSupportReactionKind, userId: String?) -> Bool {
        guard let uid = userId, let types = softSupportByUser[uid] else { return false }
        return types.contains(kind.rawValue)
    }
}
