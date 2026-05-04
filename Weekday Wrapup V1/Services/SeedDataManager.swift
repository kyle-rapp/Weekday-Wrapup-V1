import Foundation
import FirebaseFirestore

/// FILE: Services/SeedDataManager.swift
/// Seeds Firestore with realistic demo data if the feed is empty.
@MainActor
final class SeedDataManager {
    static let shared = SeedDataManager()

    private let db = Firestore.firestore()
    private init() {}

    func seedFirestoreIfEmpty() async {
        do {
            let existing = try await db.collection("posts").limit(to: 1).getDocuments()
            guard existing.documents.isEmpty else {
                print("[FIRESTORE] Seed skipped (posts already exist)")
                return
            }

            let users = Self.makeSeedUsers(count: 12)
            let posts = Self.makeSeedPosts(users: users, count: 72)

            let batch = db.batch()
            for user in users {
                let ref = db.collection("users").document(user.id)
                batch.setData([
                    "name": user.name,
                    "email": user.email,
                    "createdAt": Timestamp(date: Date()),
                    "checkInStreak": Int.random(in: 0...9),
                    "following": [] as [String]
                ], forDocument: ref, merge: true)
            }

            for post in posts {
                let ref = db.collection("posts").document(post.id)
                batch.setData(post.payload, forDocument: ref, merge: true)
            }

            try await batch.commit()
            print("[FIRESTORE] Seed complete users=\(users.count), posts=\(posts.count)")
        } catch {
            print("[ERROR] Seed failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Preview support
    static func previewSeedPosts() -> [FeedPost] {
        makeSeedPosts(users: makeSeedUsers(count: 10), count: 36).map(\.feedPost)
    }

    // MARK: - Builders
    private struct SeedUser {
        let id: String
        let name: String
        let email: String
    }

    private struct SeedPost {
        let id: String
        let payload: [String: Any]
        let feedPost: FeedPost
    }

    private static func makeSeedUsers(count: Int) -> [SeedUser] {
        let names = [
            "Avery", "Jordan", "Riley", "Cameron", "Sky", "Taylor",
            "Morgan", "Casey", "Quinn", "Rowan", "Sage", "Kai"
        ]
        return (0..<max(10, count)).map { idx in
            let name = names[idx % names.count]
            return SeedUser(
                id: "seed_user_\(idx)",
                name: name,
                email: "\(name.lowercased())\(idx)@seed.weekday.app"
            )
        }
    }

    private static func makeSeedPosts(users: [SeedUser], count: Int) -> [SeedPost] {
        let emotionPool = ["sad", "anxious", "overwhelmed", "lonely", "joyful", "peaceful", "powerful", "hopeful"]
        let emojiByEmotion: [String: String] = [
            "sad": "😢", "anxious": "😰", "overwhelmed": "😵‍💫", "lonely": "🥺",
            "joyful": "😊", "peaceful": "🌿", "powerful": "💪", "hopeful": "✨"
        ]
        let goals = [
            "Get to bed earlier", "Walk after lunch", "Journal for 5 minutes",
            "Drink more water", "Call a friend", "Take one deep breathing break"
        ]
        let insights = [
            "Today felt heavy but manageable.",
            "A short walk helped me reset.",
            "I felt more grounded after journaling.",
            "I got overwhelmed mid-day and slowed down.",
            "Small wins added up today."
        ]
        let whoops = ["Skipped lunch", "Too much screen time", "Stayed up late", ""]
        let now = Date()

        return (0..<max(50, count)).map { idx in
            let user = users[idx % users.count]
            let emotion = emotionPool[idx % emotionPool.count]
            let intensity = (idx % 10) + 1
            let date = Calendar.current.date(byAdding: .hour, value: -(idx * 3), to: now) ?? now
            let id = "seed_post_\(idx)"
            let selectedEmotions = [emotion.capitalized]
            let emoji = emojiByEmotion[emotion] ?? "✨"
            let insight = insights[idx % insights.count]
            let goal = goals[idx % goals.count]
            let tags = idx % 9 == 0 ? ["milestone"] : []

            let payload: [String: Any] = [
                "authorId": user.id,
                "userId": user.id,
                "userName": user.name,
                "weeklyEmoji": emoji,
                "emotionalInsight": insight,
                "whoopsText": whoops[idx % whoops.count],
                "weeklyGoal": goal,
                "selectedEmotions": selectedEmotions,
                "intensity": intensity,
                "createdAt": Timestamp(date: date),
                "visibility": PostVisibility.public.rawValue,
                "likeCount": Int.random(in: 0...8),
                "likedBy": [] as [String],
                "commentCount": Int.random(in: 0...5),
                "reactions": FeedReactions.defaultCounts,
                "userReactions": [:] as [String: String],
                "reactionUsers": [:] as [String: String],
                "softSupportCounts": Dictionary(uniqueKeysWithValues: SoftSupportReactionKind.allCases.map { ($0.rawValue, 0) }),
                "softSupportByUser": [:] as [String: [String]],
                "manualEntry": false,
                "helpfulTags": [HabitReinforcementEngine.normalizeActionType(goal)],
                "tags": tags
            ]

            let feedPost = FeedPost(
                id: id,
                authorId: user.id,
                user: FeedUser(id: user.id, name: user.name, streak: Int.random(in: 0...9)),
                emoji: emoji,
                insight: insight,
                whoop: whoops[idx % whoops.count],
                goal: goal,
                selectedEmotions: selectedEmotions,
                likeCount: payload["likeCount"] as? Int ?? 0,
                likedBy: [],
                commentCount: payload["commentCount"] as? Int ?? 0,
                visibility: .public,
                intensity: intensity,
                helpfulTags: [HabitReinforcementEngine.normalizeActionType(goal)],
                tags: tags,
                createdAt: date
            )

            return SeedPost(id: id, payload: payload, feedPost: feedPost)
        }
    }
}
