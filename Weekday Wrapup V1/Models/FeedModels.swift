import Foundation
import SwiftUI

enum PostVisibility: String, CaseIterable, Codable, Hashable {
    case `public` = "Public"
    case friends = "Friends"
    case `private` = "Private"
}

struct FeedUser: Identifiable, Equatable {
    let id: UUID
    var name: String
    var isFollowing: Bool
    var streak: Int

    init(id: UUID = UUID(), name: String, isFollowing: Bool = false, streak: Int = 0) {
        self.id = id
        self.name = name
        self.isFollowing = isFollowing
        self.streak = streak
    }
}

struct FeedPost: Identifiable, Equatable {
    let id: UUID
    var user: FeedUser
    var emoji: String
    var insight: String
    var whoop: String
    var goal: String
    var isLiked: Bool
    var likeCount: Int
    var comments: [String]
    var visibility: PostVisibility
    var reactions: [String: Int]

    init(
        id: UUID = UUID(),
        user: FeedUser,
        emoji: String,
        insight: String,
        whoop: String,
        goal: String,
        isLiked: Bool = false,
        likeCount: Int = 0,
        comments: [String] = [],
        visibility: PostVisibility = .public,
        reactions: [String: Int] = ["❤️": 0, "🔥": 0, "😮": 0]
    ) {
        self.id = id
        self.user = user
        self.emoji = emoji
        self.insight = insight
        self.whoop = whoop
        self.goal = goal
        self.isLiked = isLiked
        self.likeCount = likeCount
        self.comments = comments
        self.visibility = visibility
        self.reactions = reactions
    }

    static func sampleFeedPosts() -> [FeedPost] {
        let u1 = FeedUser(name: "Alice", isFollowing: false, streak: 5)
        let u2 = FeedUser(name: "Bob", isFollowing: true, streak: 2)
        let u3 = FeedUser(name: "Clara", isFollowing: false, streak: 10)
        let u4 = FeedUser(name: "Diego", isFollowing: false, streak: 3)
        let u5 = FeedUser(name: "Elena", isFollowing: true, streak: 7)
        let u6 = FeedUser(name: "Finn", isFollowing: false, streak: 1)

        return [
            FeedPost(
                user: u1,
                emoji: "😊",
                insight: "I felt productive and happy this week—small wins add up.",
                whoop: "Skipped gym once.",
                goal: "Finish reading a book",
                likeCount: 4,
                comments: ["So relatable!", "You got this 💪"],
                visibility: .public,
                reactions: ["❤️": 3, "🔥": 2, "😮": 0]
            ),
            FeedPost(
                user: u2,
                emoji: "😤",
                insight: "Frustrated but reflective. Taking breaths before I reply.",
                whoop: "Missed a deadline.",
                goal: "Organize workspace",
                isLiked: true,
                likeCount: 8,
                comments: ["Proud of you for pausing"],
                visibility: .friends,
                reactions: ["❤️": 5, "🔥": 1, "😮": 2]
            ),
            FeedPost(
                user: u3,
                emoji: "🥰",
                insight: "Loved spending time with friends. My cup is full.",
                whoop: "",
                goal: "Write journal daily",
                likeCount: 12,
                comments: ["This made me smile", "Goals 🌟", "Beautiful week"],
                visibility: .public,
                reactions: ["❤️": 8, "🔥": 4, "😮": 1]
            ),
            FeedPost(
                user: u4,
                emoji: "🌟",
                insight: "Started a new morning routine. Still wobbly but showing up.",
                whoop: "Snoozed twice.",
                goal: "Meditate 5 mornings",
                likeCount: 2,
                comments: [],
                visibility: .private,
                reactions: ["❤️": 1, "🔥": 0, "😮": 0]
            ),
            FeedPost(
                user: u5,
                emoji: "💭",
                insight: "Lots on my mind—writing it down helped untangle the noise.",
                whoop: "Overthought a text.",
                goal: "Therapy homework x2",
                likeCount: 6,
                comments: ["Journaling is underrated"],
                visibility: .friends,
                reactions: ["❤️": 2, "🔥": 3, "😮": 1]
            ),
            FeedPost(
                user: u6,
                emoji: "🎉",
                insight: "First week back after vacation—chaotic but fun.",
                whoop: "Forgot laundry.",
                goal: "Meal prep Sunday",
                likeCount: 1,
                comments: ["Welcome back!"],
                visibility: .public,
                reactions: ["❤️": 0, "🔥": 2, "😮": 0]
            )
        ]
    }
}

// MARK: - Shared feed store (local state, no backend)

final class FeedPostsStore: ObservableObject {
    static let shared = FeedPostsStore()

    @Published var posts: [FeedPost] = FeedPost.sampleFeedPosts()

    func binding(for postID: UUID) -> Binding<FeedPost> {
        Binding(
            get: {
                self.posts.first(where: { $0.id == postID })
                    ?? self.posts.first
                    ?? FeedPost(id: postID, user: FeedUser(name: "—"), emoji: "·", insight: "", whoop: "", goal: "")
            },
            set: { newValue in
                if let i = self.posts.firstIndex(where: { $0.id == postID }) {
                    self.posts[i] = newValue
                }
            }
        )
    }

    func addFromCheckIn(_ data: CheckInData) {
        let user = FeedUser(
            name: data.userName.isEmpty ? "You" : data.userName,
            isFollowing: false,
            streak: 1
        )
        let post = FeedPost(
            user: user,
            emoji: data.weeklyEmoji.isEmpty ? "✨" : data.weeklyEmoji,
            insight: data.emotionalInsight.isEmpty ? "Weekly check-in" : data.emotionalInsight,
            whoop: data.whoopsText,
            goal: data.weeklyGoal.isEmpty ? data.monthlyGoal : data.weeklyGoal,
            isLiked: false,
            likeCount: 0,
            comments: [],
            visibility: data.visibility,
            reactions: ["❤️": 0, "🔥": 0, "😮": 0]
        )
        posts.insert(post, at: 0)
    }
}
