import Foundation

/// FILE: Managers/RecommendationEngine.swift
/// Legacy single-line summary for callers that expect one string (mirrors personalized engine).

enum RecommendationEngine {

    /// One-line summary from recent wrapup-derived entries (no prefs / neutral weather).
    static func generate(from entries: [CheckInData]) -> String {
        let (emotion, intensity, tags) = PersonalizedRecommendationEngine.moodContext(from: entries)
        let recs = PersonalizedRecommendationEngine().generate(
            emotion: emotion,
            intensity: intensity,
            tags: tags,
            preferences: nil,
            history: entries,
            weather: .neutral
        )
        if let first = recs.first {
            return "\(first.title) — \(first.reason)"
        }
        return "Keep checking in with yourself."
    }
}
