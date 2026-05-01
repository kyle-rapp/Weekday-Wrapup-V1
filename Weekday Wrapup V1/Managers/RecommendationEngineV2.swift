import Foundation

/// FILE: Managers/RecommendationEngineV2.swift
/// Shared context-aware scoring helpers for recommendation ranking.

struct RecommendationContext {
    let emotion: String
    let intensity: Int
    let preferences: [String]
    let isNight: Bool
    let weather: String?
    let likedRecommendations: Set<UUID>
    let dislikedRecommendations: Set<UUID>
}

func scoreRecommendation(_ rec: Recommendation, context: RecommendationContext) -> Double {
    var score = 0.0

    if rec.emotionTargets.contains(where: { $0.caseInsensitiveCompare(context.emotion) == .orderedSame }) {
        score += 5
    }

    if rec.intensityRange.contains(context.intensity) {
        score += 3
    }

    let matchCount = rec.tags.filter { tag in
        context.preferences.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
    }.count
    score += Double(matchCount)

    if context.isNight && rec.tags.contains(where: { $0.caseInsensitiveCompare("calm") == .orderedSame }) {
        score += 2
    }

    if context.weather?.lowercased() == "sunny"
        && rec.tags.contains(where: { $0.caseInsensitiveCompare("outdoor") == .orderedSame }) {
        score += 2
    }

    if context.likedRecommendations.contains(rec.id) {
        score += 4
    }

    if context.dislikedRecommendations.contains(rec.id) {
        score -= 6
    }

    return score
}

func rankedRecommendations(from recs: [Recommendation], context: RecommendationContext) -> [Recommendation] {
    let ranked = recs
        .map { ($0, scoreRecommendation($0, context: context)) }
        .sorted { $0.1 > $1.1 }

    return Array(ranked.prefix(5)).map { $0.0 }
}

