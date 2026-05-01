import SwiftUI

/// FILE: Views/Feed/FeedEmotionPalette.swift
/// Capsule / accent colors from the **emotion label**, not intensity (avoids “peaceful + high intensity → red”).

enum FeedEmotionPalette {

    static func accent(for emotionLabel: String) -> Color {
        let e = emotionLabel.lowercased()
        if e.contains("peace") || e.contains("calm") || e.contains("content")
            || e.contains("hopeful") || (e.contains("hope") && !e.contains("hopeless")) {
            return Color(red: 0.2, green: 0.55, blue: 0.45)
        }
        if e.contains("happy") || e.contains("joy") || e.contains("excited") || e.contains("cheerful") {
            return Color(red: 0.85, green: 0.65, blue: 0.12)
        }
        if e.contains("sad") || e.contains("hurt") || e.contains("lonely") || e.contains("depress") || e.contains("grief") {
            return Color(red: 0.25, green: 0.45, blue: 0.85)
        }
        if e.contains("angry") || e.contains("mad") || e.contains("frustrat") || e.contains("rage") || e.contains("hostile") {
            return Color(red: 0.85, green: 0.28, blue: 0.28)
        }
        if e.contains("anx") || e.contains("worried") || e.contains("nervous") || e.contains("scared") || e.contains("panic") {
            return Color(red: 0.45, green: 0.32, blue: 0.75)
        }
        return Color.secondary
    }

    static func chipBackground(for emotionLabel: String) -> Color {
        accent(for: emotionLabel).opacity(0.16)
    }

    static func chipForeground(for emotionLabel: String) -> Color {
        accent(for: emotionLabel).opacity(0.95)
    }

    /// Reaction row idle slot fill — emotion-tinted instead of generic orange.
    static func reactionSlotFill(for post: FeedPost, selected: Bool) -> Color {
        let label = post.primaryEmotionDisplayLabel
        if selected { return Color.accentColor.opacity(0.18) }
        return accent(for: label).opacity(0.12)
    }
}
