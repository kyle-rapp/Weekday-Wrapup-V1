import Foundation

/// FILE: Managers/RecommendationEngineV2.swift
/// Shared context-aware scoring helpers for recommendation ranking.

struct RecommendationContext {
    let emotion: String
    let intensity: Int
    let preferences: [String]
    let likedRecommendations: Set<String>
    let dislikedRecommendations: Set<String>
    let memory: [String: RecommendationMemory]
    let habitInsights: [HabitInsight]
    let currentTime: Date
    let weather: String?
}

func scoreRecommendation(_ rec: Recommendation, context: RecommendationContext) -> Double {
    var score = 0.0
    let recId = rec.id.uuidString
    let memory = context.memory[recId]

    if rec.emotionTargets.contains(where: { $0.caseInsensitiveCompare(context.emotion) == .orderedSame }) {
        score += 5
    }

    if rec.intensityRange.contains(context.intensity) {
        score += 3
    }

    let matchCount = rec.tags.filter { tag in
        context.preferences.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
    }.count
    score += Double(matchCount) * 1.5

    if context.likedRecommendations.contains(recId) {
        score += 4
    }

    if context.dislikedRecommendations.contains(recId) {
        score -= 6
    }

    if let memory {
        score += Double(memory.timesAccepted) * 2.5
        score -= Double(memory.timesDismissed) * 2.0

        if let lastShown = memory.lastShownAt,
           context.currentTime.timeIntervalSince(lastShown) < 86_400 {
            score -= 3
        }

        score += Double(memory.streakAccepted) * 1.2
    }

    let hour = Calendar.current.component(.hour, from: context.currentTime)
    if hour >= 21 && rec.tags.contains(where: { $0.caseInsensitiveCompare("calm") == .orderedSame }) {
        score += 2
    }
    if hour <= 10 && rec.tags.contains(where: { $0.caseInsensitiveCompare("energizing") == .orderedSame }) {
        score += 2
    }

    if context.weather?.caseInsensitiveCompare("sunny") == .orderedSame
        && rec.tags.contains(where: { $0.caseInsensitiveCompare("outdoor") == .orderedSame }) {
        score += 2
    }

    if let insight = context.habitInsights.first(where: { insight in
        let action = HabitReinforcementEngine.normalizeActionType(insight.actionType)
        if action == rec.type.rawValue.lowercased() {
            return true
        }
        return rec.tags.contains(where: {
            HabitReinforcementEngine.normalizeActionType($0) == action
        })
    }) {
        score += insight.improvementScore * 2
    }

    return score
}

func shouldShow(_ rec: Recommendation, context: RecommendationContext) -> Bool {
    guard let memory = context.memory[rec.id.uuidString] else {
        return true
    }

    if memory.timesDismissed >= 3 {
        return false
    }

    if let lastShown = memory.lastShownAt,
       context.currentTime.timeIntervalSince(lastShown) < 3600 {
        return false
    }

    return true
}

func rankedRecommendations(from recs: [Recommendation], context: RecommendationContext) -> [Recommendation] {
    let ranked = recs
        .map { ($0, scoreRecommendation($0, context: context)) }
        .sorted { $0.1 > $1.1 }

    return ranked
        .map { $0.0 }
        .filter { shouldShow($0, context: context) }
        .prefix(3)
        .map { $0 }
}

