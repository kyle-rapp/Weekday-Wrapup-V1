import Foundation

/// FILE: Managers/ReactionManager.swift
/// Contextual quick reactions for the feed (4 + expand). Keys are Firestore `reactions` map keys.

enum ReactionManager {

    /// Four emoji keys for the compact row, driven by the post’s **first** saved emotion.
    static func emotionBasedEmojis(for post: FeedPost) -> [String] {
        let list = EmojiRecommender.emojis(emotion: post.primaryEmotion, intensity: post.intensity ?? 5)
        return Array(list.prefix(4))
    }

    static func emojiForEmotionLabel(_ emotion: String) -> String {
        let e = emotion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if e.contains("sad") || e.contains("lonely") || e.contains("hurt") || e.contains("depressed") { return "😢" }
        if e.contains("angry") || e.contains("mad") || e.contains("frustrated") { return "😤" }
        if e.contains("scared") || e.contains("anxious") || e.contains("worried") { return "😰" }
        if e.contains("joy") || e.contains("happy") || e.contains("excited") { return "😊" }
        if e.contains("peace") || e.contains("calm") { return "🌿" }
        if e.contains("powerful") || e.contains("proud") { return "💪" }
        return "✨"
    }
}

enum EmojiRecommender {
    static func emojis(emotion: String, intensity: Int) -> [String] {
        let e = emotion.lowercased()
        let level = max(1, min(10, intensity))

        if e.contains("sad") || e.contains("hurt") || e.contains("lonely") {
            return level >= 7 ? ["❤️", "🤗", "🙏", "💛"] : ["💛", "🤗", "🌿", "🙏"]
        } else if e.contains("anxious") || e.contains("worried") || e.contains("scared") {
            return level >= 7 ? ["🌿", "🫶", "💙", "🧠"] : ["💙", "🌿", "🫶", "🙏"]
        } else if e.contains("happy") || e.contains("joy") || e.contains("joyful") || e.contains("excited") {
            return ["🔥", "🎉", "😄", "💫"]
        } else if e.contains("angry") || e.contains("mad") || e.contains("frustrated") {
            return ["🫶", "🙏", "💪", "🌿"]
        }

        return ["❤️", "🙏", "💬", "✨"]
    }
}
