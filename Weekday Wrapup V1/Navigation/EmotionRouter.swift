// FILE: Navigation/EmotionRouter.swift
import SwiftUI

/// Single source of truth for `FeelingWheelView` selection across Share and Learn tabs.
/// Owned by the app root as `@StateObject` and injected with `@EnvironmentObject`.
@MainActor
final class EmotionRouter: ObservableObject {
    @Published var selectedEmotions: Set<String> = []
    @Published var lastSelectedEmotion: String?

    func updateSelection(_ newValue: Set<String>) {
        selectedEmotions = newValue

        if let primary = Self.preferredDisplayKey(in: newValue) {
            lastSelectedEmotion = primary
        } else {
            lastSelectedEmotion = nil
        }

        print("EmotionRouter update:")
        print("selectedEmotions:", newValue)
        print("lastSelectedEmotion:", lastSelectedEmotion ?? "nil")
    }

    /// Deterministic key for non-empty sets; `nil` only when `set` is empty.
    static func preferredDisplayKey(in set: Set<String>) -> String? {
        guard !set.isEmpty else { return nil }
        return set.sorted().first
    }
}
