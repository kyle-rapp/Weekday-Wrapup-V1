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

    init(id: UUID = UUID(), title: String, reason: String, action: String, type: RecommendationType) {
        self.id = id
        self.title = title
        self.reason = reason
        self.action = action
        self.type = type
    }
}

/// Weather hint passed into the recommendation engine (from WeatherKit when available).
enum RecommendationWeatherHint: String, Equatable, Hashable {
    case sunny
    case rainy
    case neutral
}
