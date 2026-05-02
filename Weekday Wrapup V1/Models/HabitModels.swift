import Foundation

/// FILE: Models/HabitModels.swift
/// Habit reinforcement tracking models used by Grow insights.
struct HabitSignal: Codable, Identifiable, Equatable, Hashable {
    let id: UUID

    let userId: String
    let actionType: String // "journal", "walk", "breathing", etc

    let emotionBefore: String
    let emotionAfter: String?

    let intensityBefore: Int
    let intensityAfter: Int?

    let createdAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        actionType: String,
        emotionBefore: String,
        emotionAfter: String?,
        intensityBefore: Int,
        intensityAfter: Int?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.actionType = actionType
        self.emotionBefore = emotionBefore
        self.emotionAfter = emotionAfter
        self.intensityBefore = intensityBefore
        self.intensityAfter = intensityAfter
        self.createdAt = createdAt
    }

    func asFirestoreDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    static func fromFirestoreDictionary(_ dict: [String: Any]) throws -> HabitSignal {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [])
        return try JSONDecoder().decode(HabitSignal.self, from: data)
    }
}

struct HabitInsight: Equatable, Hashable {
    let actionType: String
    let improvementScore: Double
    let usageCount: Int
    let lastUsed: Date?
}

struct HabitStreak: Equatable, Hashable {
    let actionType: String
    let currentStreak: Int
    let longestStreak: Int
}
