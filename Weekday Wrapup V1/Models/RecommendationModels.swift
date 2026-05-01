import Foundation

/// FILE: Models/RecommendationModels.swift
/// Structured coaching items for the Grow tab (v1 rule-based engine).

enum RecommendationType: String, Codable, CaseIterable, Hashable {
    case regulation
    case reflection
    case action
    case connection
}

struct Recommendation: Identifiable, Equatable, Hashable {
    let id: UUID
    let title: String
    let reason: String
    let action: String
    let type: RecommendationType
    /// V2 scoring metadata.
    let tags: [String]
    let emotionTargets: [String]
    let intensityRange: ClosedRange<Int>

    init(
        id: UUID = UUID(),
        title: String,
        reason: String,
        action: String,
        type: RecommendationType,
        tags: [String] = [],
        emotionTargets: [String] = [],
        intensityRange: ClosedRange<Int> = 1 ... 10
    ) {
        self.id = id
        self.title = title
        self.reason = reason
        self.action = action
        self.type = type
        self.tags = tags
        self.emotionTargets = emotionTargets
        self.intensityRange = intensityRange
    }
}

/// Weather hint passed into the recommendation engine (from WeatherKit when available).
enum RecommendationWeatherHint: String, Equatable, Hashable {
    case sunny
    case rainy
    case neutral
}
