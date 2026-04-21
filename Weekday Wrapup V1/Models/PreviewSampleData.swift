#if DEBUG
import Foundation

/// FILE: Models/PreviewSampleData.swift
/// Static mock data for SwiftUI Previews (no Firebase).
enum PreviewSampleData {
    static let currentUser = AppUser(
        id: "preview-user-id",
        name: "Alex",
        email: "alex@example.com",
        createdAt: Date()
    )

    static let sampleComments: [Comment] = [
        Comment(id: "c1", userId: "user-bob", userName: "Bob", text: "Love this energy!", createdAt: Date().addingTimeInterval(-3600)),
        Comment(id: "c2", userId: "preview-user-id", userName: "Alex", text: "Same here 💛", createdAt: Date().addingTimeInterval(-1200))
    ]

    static let sampleFeedPosts: [FeedPost] = [
        FeedPost(
            id: "post-1",
            authorId: "user-alice",
            user: FeedUser(id: "user-alice", name: "Alice", streak: 5),
            emoji: "😊",
            insight: "Felt productive and kind to myself this week.",
            whoop: "Skipped one workout.",
            goal: "Read 50 pages",
            likeCount: 4,
            likedBy: ["preview-user-id"],
            reactions: ["❤️": 3, "🔥": 2, "😮": 0],
            userReactions: ["preview-user-id": "❤️"],
            comments: [],
            commentCount: 2,
            visibility: .public,
            createdAt: Date().addingTimeInterval(-7200)
        ),
        FeedPost(
            id: "post-2",
            authorId: "user-bob",
            user: FeedUser(id: "user-bob", name: "Bob", streak: 2),
            emoji: "💭",
            insight: "Journaling helped quiet the noise.",
            whoop: "",
            goal: "Therapy homework x2",
            likeCount: 1,
            likedBy: [],
            reactions: ["❤️": 1, "🔥": 1, "😮": 0],
            userReactions: [:],
            comments: [],
            commentCount: 0,
            visibility: .friends,
            createdAt: Date().addingTimeInterval(-86400)
        ),
        FeedPost(
            id: "post-3",
            authorId: "user-clara",
            user: FeedUser(id: "user-clara", name: "Clara", streak: 10),
            emoji: "🎉",
            insight: "Small wins: I showed up even when I didn’t want to.",
            whoop: "Forgot laundry.",
            goal: "Meal prep Sunday",
            likeCount: 8,
            likedBy: [],
            reactions: ["❤️": 5, "🔥": 3, "😮": 1],
            userReactions: [:],
            comments: [],
            commentCount: 1,
            visibility: .public,
            createdAt: Date().addingTimeInterval(-172800)
        )
    ]
}
#endif
