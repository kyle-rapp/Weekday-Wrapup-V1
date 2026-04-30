// FILE: Navigation/EmotionRouter.swift
import Foundation
import SwiftUI

/// Share vs Learn wheel state are isolated. Updates use separate `[String]` APIs — never mix bindings.
@MainActor
final class EmotionRouter: ObservableObject {
    @Published var learnEmotions: [String] = []
    @Published var shareEmotions: [String] = []
    @Published var lastSelectedEmotion: String?
    @Published var lastSelectedLearn: String?
    @Published var history: [EmotionEntry] = []

    private static let historyKey = "emotionHistoryEntries"
    private static let maxHistoryEntries = 200

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.historyKey),
           let decoded = try? JSONDecoder().decode([EmotionEntry].self, from: data) {
            history = decoded
        }
    }

    func updateLearnSelection(_ emotions: [String]) {
        learnEmotions = emotions
        lastSelectedLearn = Self.preferredDisplayKey(in: Set(emotions))
    }

    func updateShareSelection(_ emotions: [String]) {
        shareEmotions = emotions
        lastSelectedEmotion = Self.preferredDisplayKey(in: Set(emotions))
    }

    /// Call after a successful feed post from Share.
    func saveEntry() {
        guard !shareEmotions.isEmpty else { return }
        let entry = EmotionEntry(
            id: UUID(),
            date: Date(),
            emotions: shareEmotions
        )
        history.insert(entry, at: 0)
        if history.count > Self.maxHistoryEntries {
            history = Array(history.prefix(Self.maxHistoryEntries))
        }
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: Self.historyKey)
        }
    }

    /// Restore Share wheel from UserDefaults draft (sorted strings).
    func restoreShareDraft(from sortedStrings: [String]) {
        let unique = Array(Set(sortedStrings)).sorted()
        updateShareSelection(unique)
    }

    /// Prefer a secondary label in `set` over its primary wedge so definitions match the tapped ring word.
    static func preferredDisplayKey(in set: Set<String>) -> String? {
        guard !set.isEmpty else { return nil }

        for (_, secondaries) in FeelingWheelView.emotionMap {
            for emotion in set {
                if secondaries.contains(where: { $0.caseInsensitiveCompare(emotion) == .orderedSame }) {
                    return emotion
                }
            }
        }

        let primaryOrder = ["Joyful", "Powerful", "Peaceful", "Sad", "Mad", "Scared"]
        for primary in primaryOrder where FeelingWheelView.emotionMap[primary] != nil {
            if set.contains(primary) {
                return primary
            }
        }

        return set.sorted().first
    }
}
