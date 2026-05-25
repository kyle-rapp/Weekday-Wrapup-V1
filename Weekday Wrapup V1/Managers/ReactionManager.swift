import Foundation

/// FILE: Managers/ReactionManager.swift
/// Contextual quick reactions for the feed (4 + expand). Keys are Firestore `reactions` map keys.

enum ReactionManager {

    /// Four emoji keys for the compact row, driven by the post's **first** saved emotion.
    static func emotionBasedEmojis(for post: FeedPost) -> [String] {
        let list = EmojiRecommender.emojis(emotion: post.primaryEmotion, intensity: post.intensity ?? 5)
        return Array(list.prefix(4))
    }

    static func emojiForEmotionLabel(_ emotion: String) -> String {
        let e = emotion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if e.contains("sad") || e.contains("lonely") || e.contains("hurt") || e.contains("depressed") { return "😢" }
        if e.contains("angry") || e.contains("mad") || e.contains("frustrated") || e.contains("hostile") { return "😡" }
        if e.contains("scared") || e.contains("anxious") || e.contains("worried") || e.contains("confused") { return "😨" }
        if e.contains("joy") || e.contains("happy") || e.contains("excited") || e.contains("cheerful") { return "😄" }
        if e.contains("peace") || e.contains("calm") || e.contains("content") || e.contains("trusting") { return "😌" }
        if e.contains("powerful") || e.contains("proud") || e.contains("aware") { return "💪" }
        return "✨"
    }
}

enum EmojiRecommender {
    static func emojis(emotion: String, intensity: Int) -> [String] {
        let e = emotion.lowercased()

        if e.contains("mad") || e.contains("angry") || e.contains("frustrated") ||
           e.contains("hostile") || e.contains("hateful") || e.contains("hurt") {
            return ["😡", "😠", "😤", "🤬"]
        } else if e.contains("sad") || e.contains("lonely") || e.contains("depressed") ||
                  e.contains("ashamed") || e.contains("guilty") || e.contains("bored") {
            return ["😢", "😞", "💔", "😢"]
        } else if e.contains("scared") || e.contains("anxious") || e.contains("worried") ||
                  e.contains("helpless") || e.contains("confused") || e.contains("rejected") ||
                  e.contains("insecure") || e.contains("submissive") || e.contains("critical") {
            return ["😨", "😰", "😟", "🌩️"]
        } else if e.contains("joy") || e.contains("joyful") || e.contains("happy") ||
                  e.contains("excited") || e.contains("cheerful") || e.contains("hopeful") ||
                  e.contains("energetic") || e.contains("sensuous") || e.contains("creative") {
            return ["😄", "✨", "🎉", "😄"]
        } else if e.contains("powerful") || e.contains("proud") || e.contains("respected") ||
                  e.contains("appreciated") || e.contains("important") || e.contains("faithful") ||
                  e.contains("aware") {
            return ["💪", "👑", "⚡", "🚀"]
        } else if e.contains("peace") || e.contains("peaceful") || e.contains("calm") ||
                  e.contains("content") || e.contains("loving") || e.contains("trusting") ||
                  e.contains("nurturing") || e.contains("intimate") || e.contains("thoughtful") {
            return ["😌", "🌱", "🍃", "🕊️"]
        }

        return ["❤️", "🙏", "💬", "✨"]
    }
}
