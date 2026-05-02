import Foundation

/// FILE: Models/RecommendationMemory.swift
/// Per-user recommendation memory at `users/{uid}/recommendationMemory/{recommendationId}`.
struct RecommendationMemory: Codable, Equatable {
    let recommendationId: String

    var timesShown: Int
    var timesAccepted: Int
    var timesDismissed: Int

    var lastShownAt: Date?
    var lastAcceptedAt: Date?

    var streakAccepted: Int

    init(
        recommendationId: String,
        timesShown: Int = 0,
        timesAccepted: Int = 0,
        timesDismissed: Int = 0,
        lastShownAt: Date? = nil,
        lastAcceptedAt: Date? = nil,
        streakAccepted: Int = 0
    ) {
        self.recommendationId = recommendationId
        self.timesShown = timesShown
        self.timesAccepted = timesAccepted
        self.timesDismissed = timesDismissed
        self.lastShownAt = lastShownAt
        self.lastAcceptedAt = lastAcceptedAt
        self.streakAccepted = streakAccepted
    }

    func asFirestoreDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    static func fromFirestoreDictionary(_ dict: [String: Any], fallbackRecommendationId: String) throws -> RecommendationMemory {
        var raw = dict
        if raw["recommendationId"] == nil {
            raw["recommendationId"] = fallbackRecommendationId
        }
        let jsonData = try JSONSerialization.data(withJSONObject: raw, options: [])
        return try JSONDecoder().decode(RecommendationMemory.self, from: jsonData)
    }
}
