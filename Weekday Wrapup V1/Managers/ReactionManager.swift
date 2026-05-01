import Foundation

/// FILE: Managers/ReactionManager.swift
/// Contextual quick reactions for the feed (4 + expand). Keys are Firestore `reactions` map keys.

enum ReactionManager {

    /// Four emoji keys for the compact row, driven by the post’s **first** saved emotion.
    static func emotionBasedEmojis(for post: FeedPost) -> [String] {
        let emotion = post.primaryEmotion

        if emotion.contains("sad") || emotion.contains("hurt") {
            return ["🤍", "😢", "🙏", "💛"]
        } else if emotion.contains("angry") || emotion.contains("mad") {
            return ["🔥", "💥", "😤", "🫂"]
        } else if emotion.contains("happy") || emotion.contains("joy") || emotion.contains("joyful") || emotion.contains("cheerful") || emotion.contains("excited") {
            return ["❤️", "🔥", "😊", "🎉"]
        } else if emotion.contains("peace") || emotion.contains("peaceful") || emotion.contains("calm") || emotion.contains("content")
            || emotion.contains("hopeful") || (emotion.contains("hope") && !emotion.contains("hopeless")) {
            return ["🌿", "💙", "✨", "🙏"]
        } else {
            return ["❤️", "🙏", "💬", "✨"]
        }
    }
}
