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
        id: UUID? = nil,
        title: String,
        reason: String,
        action: String,
        type: RecommendationType,
        tags: [String] = [],
        emotionTargets: [String] = [],
        intensityRange: ClosedRange<Int> = 1 ... 10
    ) {
        self.id = id ?? Self.stableID(
            title: title,
            reason: reason,
            action: action,
            type: type,
            tags: tags
        )
        self.title = title
        self.reason = reason
        self.action = action
        self.type = type
        self.tags = tags
        self.emotionTargets = emotionTargets
        self.intensityRange = intensityRange
    }

    private static func stableID(
        title: String,
        reason: String,
        action: String,
        type: RecommendationType,
        tags: [String]
    ) -> UUID {
        let normalized = [
            title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            reason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            type.rawValue,
            tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.sorted().joined(separator: ",")
        ].joined(separator: "|")

        func fnv1a64(_ text: String, seed: UInt64 = 0xcbf29ce484222325) -> UInt64 {
            var hash = seed
            let prime: UInt64 = 1099511628211
            for byte in text.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* prime
            }
            return hash
        }

        let first = fnv1a64(normalized, seed: 0xcbf29ce484222325)
        let second = fnv1a64(normalized + "|weekday_wrapup_v1", seed: 0x84222325cbf29ce4)
        let hex = String(format: "%016llx%016llx", first, second)
        let uuidString = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
        return UUID(uuidString: String(uuidString)) ?? UUID()
    }
}

/// Weather hint passed into the recommendation engine (from WeatherKit when available).
enum RecommendationWeatherHint: String, Equatable, Hashable {
    case sunny
    case rainy
    case neutral
}
