import Foundation

/// FILE: Managers/HabitReinforcementEngine.swift
/// Builds habit signals/insights/streaks from check-in behavior.
enum HabitReinforcementEngine {
    static let sameSessionWindow: TimeInterval = 2 * 60 * 60

    static func improvementScore(before: Int, after: Int) -> Double {
        Double(before - after)
    }

    static func buildHabitInsights(signals: [HabitSignal]) -> [HabitInsight] {
        var map: [String: [Double]] = [:]
        var usage: [String: Int] = [:]
        var lastUsed: [String: Date] = [:]

        for signal in signals {
            guard let after = signal.intensityAfter else { continue }
            let score = improvementScore(before: signal.intensityBefore, after: after)
            map[signal.actionType, default: []].append(score)
            usage[signal.actionType, default: 0] += 1
            if let current = lastUsed[signal.actionType] {
                lastUsed[signal.actionType] = max(current, signal.createdAt)
            } else {
                lastUsed[signal.actionType] = signal.createdAt
            }
        }

        return map.map { key, values in
            HabitInsight(
                actionType: key,
                improvementScore: values.reduce(0, +) / Double(max(1, values.count)),
                usageCount: usage[key] ?? 0,
                lastUsed: lastUsed[key]
            )
        }
        .sorted { $0.improvementScore > $1.improvementScore }
    }

    static func updateStreak(current: Int, improved: Bool) -> Int {
        improved ? current + 1 : 0
    }

    static func buildHabitStreaks(signals: [HabitSignal]) -> [HabitStreak] {
        let sorted = signals.sorted { $0.createdAt < $1.createdAt }
        var currentByType: [String: Int] = [:]
        var longestByType: [String: Int] = [:]

        for signal in sorted {
            guard let after = signal.intensityAfter else { continue }
            let improved = (signal.intensityBefore - after) >= 2
            let current = currentByType[signal.actionType] ?? 0
            let next = updateStreak(current: current, improved: improved)
            currentByType[signal.actionType] = next
            longestByType[signal.actionType] = max(longestByType[signal.actionType] ?? 0, next)
        }

        return currentByType.keys.sorted().map { action in
            HabitStreak(
                actionType: action,
                currentStreak: currentByType[action] ?? 0,
                longestStreak: longestByType[action] ?? 0
            )
        }
    }

    /// Derives behavior signals from consecutive check-ins in the same session (<= 2h apart).
    static func deriveSignals(from entries: [CheckInData], userId: String) -> [HabitSignal] {
        let sorted = entries.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return [] }
        var out: [HabitSignal] = []

        for idx in 1..<sorted.count {
            let before = sorted[idx - 1]
            let after = sorted[idx]
            let delta = after.date.timeIntervalSince(before.date)
            guard delta >= 0, delta <= sameSessionWindow else { continue }
            guard let beforeIntensity = before.intensity, let afterIntensity = after.intensity else { continue }

            let actions = actionTypes(from: after)
            guard !actions.isEmpty else { continue }

            for action in actions {
                out.append(
                    HabitSignal(
                        userId: userId,
                        actionType: action,
                        emotionBefore: before.firstSelectedEmotionLabel,
                        emotionAfter: after.firstSelectedEmotionLabel,
                        intensityBefore: beforeIntensity,
                        intensityAfter: afterIntensity,
                        createdAt: after.date
                    )
                )
            }
        }

        return out
    }

    static func actionTypes(from entry: CheckInData) -> [String] {
        var raw = (entry.helpfulTags ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        let note = (entry.whatHelped ?? "").lowercased()
        if note.contains("journal") || note.contains("write") { raw.append("journal") }
        if note.contains("walk") || note.contains("outside") { raw.append("walk") }
        if note.contains("breath") || note.contains("breathing") || note.contains("box breathing") { raw.append("breathing") }
        if note.contains("meditat") { raw.append("breathing") }

        let normalized = raw.map(normalizeActionType)
        return Array(Set(normalized)).sorted()
    }

    static func normalizeActionType(_ raw: String) -> String {
        let value = raw.lowercased()
        if value.contains("journal") || value.contains("write") { return "journal" }
        if value.contains("walk") || value.contains("outside") || value.contains("run") { return "walk" }
        if value.contains("breath") || value.contains("ground") || value.contains("calm") || value.contains("meditat") { return "breathing" }
        if value.contains("talk") || value.contains("friend") || value.contains("call") || value.contains("text") { return "connection" }
        return value
    }
}
