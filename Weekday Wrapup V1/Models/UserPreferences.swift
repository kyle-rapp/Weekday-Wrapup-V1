import Foundation

/// FILE: Models/UserPreferences.swift
/// Stored at `users/{userId}/preferences/profile` (optional fields; safe for older clients).

struct UserPreferences: Codable, Equatable, Hashable {
    var enjoysWalking: Bool?
    var hasPet: Bool?
    var journals: Bool?
    var meditates: Bool?
    var callsFriends: Bool?
    var creativeOutlets: [String]?

    var drinksAlcohol: Bool?
    var relationshipStatus: String?

    var pronouns: String?

    var topJoyActivities: [String]
    var topStressors: [String]

    var preferredCopingStyles: [String]?

    init(
        enjoysWalking: Bool? = nil,
        hasPet: Bool? = nil,
        journals: Bool? = nil,
        meditates: Bool? = nil,
        callsFriends: Bool? = nil,
        creativeOutlets: [String]? = nil,
        drinksAlcohol: Bool? = nil,
        relationshipStatus: String? = nil,
        pronouns: String? = nil,
        topJoyActivities: [String] = [],
        topStressors: [String] = [],
        preferredCopingStyles: [String]? = nil
    ) {
        self.enjoysWalking = enjoysWalking
        self.hasPet = hasPet
        self.journals = journals
        self.meditates = meditates
        self.callsFriends = callsFriends
        self.creativeOutlets = creativeOutlets
        self.drinksAlcohol = drinksAlcohol
        self.relationshipStatus = relationshipStatus
        self.pronouns = pronouns
        self.topJoyActivities = Array(topJoyActivities.prefix(5))
        self.topStressors = Array(topStressors.prefix(5))
        self.preferredCopingStyles = preferredCopingStyles
    }

    private enum CodingKeys: String, CodingKey {
        case enjoysWalking, hasPet, journals, meditates, callsFriends, creativeOutlets
        case drinksAlcohol, relationshipStatus, pronouns
        case topJoyActivities, topStressors, preferredCopingStyles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enjoysWalking = try c.decodeIfPresent(Bool.self, forKey: .enjoysWalking)
        hasPet = try c.decodeIfPresent(Bool.self, forKey: .hasPet)
        journals = try c.decodeIfPresent(Bool.self, forKey: .journals)
        meditates = try c.decodeIfPresent(Bool.self, forKey: .meditates)
        callsFriends = try c.decodeIfPresent(Bool.self, forKey: .callsFriends)
        creativeOutlets = try c.decodeIfPresent([String].self, forKey: .creativeOutlets)
        drinksAlcohol = try c.decodeIfPresent(Bool.self, forKey: .drinksAlcohol)
        relationshipStatus = try c.decodeIfPresent(String.self, forKey: .relationshipStatus)
        pronouns = try c.decodeIfPresent(String.self, forKey: .pronouns)
        topJoyActivities = Array((try c.decodeIfPresent([String].self, forKey: .topJoyActivities) ?? []).prefix(5))
        topStressors = Array((try c.decodeIfPresent([String].self, forKey: .topStressors) ?? []).prefix(5))
        preferredCopingStyles = try c.decodeIfPresent([String].self, forKey: .preferredCopingStyles)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(enjoysWalking, forKey: .enjoysWalking)
        try c.encodeIfPresent(hasPet, forKey: .hasPet)
        try c.encodeIfPresent(journals, forKey: .journals)
        try c.encodeIfPresent(meditates, forKey: .meditates)
        try c.encodeIfPresent(callsFriends, forKey: .callsFriends)
        try c.encodeIfPresent(creativeOutlets, forKey: .creativeOutlets)
        try c.encodeIfPresent(drinksAlcohol, forKey: .drinksAlcohol)
        try c.encodeIfPresent(relationshipStatus, forKey: .relationshipStatus)
        try c.encodeIfPresent(pronouns, forKey: .pronouns)
        try c.encode(topJoyActivities, forKey: .topJoyActivities)
        try c.encode(topStressors, forKey: .topStressors)
        try c.encodeIfPresent(preferredCopingStyles, forKey: .preferredCopingStyles)
    }

    /// Flat dictionary for Firestore `setData(_:merge:)`.
    func asFirestoreDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }

    static func fromFirestoreDictionary(_ dict: [String: Any]) throws -> UserPreferences {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(UserPreferences.self, from: data)
    }
}
