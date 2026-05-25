import Foundation

struct UserAdaptiveProfile: Codable, Equatable {
    // POSITIVE REINFORCEMENT
    var helpfulActivityScores: [String: Double]

    // NEGATIVE OR OVERUSED PATTERNS
    var unhealthyPatternScores: [String: Double]

    // CATEGORY PREFERENCES
    var categoryAffinities: [String: Double]

    // TIME / CONTEXT PATTERNS
    var emotionalContextScores: [String: Double]

    // RECENCY MEMORY
    var recentSuccessfulActions: [String]

    // LONG TERM SIGNALS
    var stabilizationScore: Double

    init(
        helpfulActivityScores: [String: Double] = [:],
        unhealthyPatternScores: [String: Double] = [:],
        categoryAffinities: [String: Double] = [:],
        emotionalContextScores: [String: Double] = [:],
        recentSuccessfulActions: [String] = [],
        stabilizationScore: Double = 0
    ) {
        self.helpfulActivityScores = helpfulActivityScores
        self.unhealthyPatternScores = unhealthyPatternScores
        self.categoryAffinities = categoryAffinities
        self.emotionalContextScores = emotionalContextScores
        self.recentSuccessfulActions = recentSuccessfulActions
        self.stabilizationScore = stabilizationScore
    }

    func asFirestoreDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    static func fromFirestoreDictionary(_ dict: [String: Any]) throws -> UserAdaptiveProfile {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [])
        return try JSONDecoder().decode(UserAdaptiveProfile.self, from: data)
    }
}
