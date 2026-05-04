import Foundation

struct Reaction: Codable, Hashable {
    let postId: String
    let userId: String
    let emoji: String
}

struct SeedData {
    static let users: [AppUser] = [
        AppUser(id: "seed-user-1", name: "TestUser1", email: "testuser1@weekday.app"),
        AppUser(id: "seed-user-2", name: "TestUser2", email: "testuser2@weekday.app"),
        AppUser(id: "seed-user-3", name: "Taylor", email: "taylor@weekday.app")
    ]

    static let posts: [FeedPost] = [
        FeedPost(
            id: "seed-post-1",
            authorId: "seed-user-1",
            user: FeedUser(id: "seed-user-1", name: "TestUser1", streak: 2),
            emoji: "🌿",
            insight: "Feeling calmer after a short walk.",
            whoop: "Got outside before work.",
            goal: "Repeat this tomorrow",
            selectedEmotions: ["peaceful"],
            intensity: 4,
            createdAt: Date().addingTimeInterval(-3600 * 6)
        ),
        FeedPost(
            id: "seed-post-2",
            authorId: "seed-user-2",
            user: FeedUser(id: "seed-user-2", name: "TestUser2", streak: 1),
            emoji: "💪",
            insight: "Overwhelmed but making progress one step at a time.",
            whoop: "Finished the hardest task first.",
            goal: "Protect one focus block",
            selectedEmotions: ["overwhelmed"],
            intensity: 8,
            createdAt: Date().addingTimeInterval(-3600 * 12)
        ),
        FeedPost(
            id: "seed-post-3",
            authorId: "seed-user-3",
            user: FeedUser(id: "seed-user-3", name: "Taylor", streak: 5),
            emoji: "✨",
            insight: "Grateful for a steadier day.",
            whoop: "Reached out to a friend.",
            goal: "Journal before bed",
            selectedEmotions: ["hopeful"],
            intensity: 5,
            createdAt: Date().addingTimeInterval(-3600 * 20)
        )
    ]

    static let reactions: [Reaction] = [
        Reaction(postId: "seed-post-1", userId: "seed-user-2", emoji: "❤️"),
        Reaction(postId: "seed-post-2", userId: "seed-user-1", emoji: "🫶"),
        Reaction(postId: "seed-post-3", userId: "seed-user-2", emoji: "👏")
    ]
}
