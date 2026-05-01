import Foundation

/// FILE: Models/ProfileDetails.swift
/// `users/{userId}/profile/details` — insight summary and lightweight flags (never auto-published).

struct ProfileDetails: Codable, Equatable, Hashable {
    var insightSummary: String?
    var insightPromptDismissed: Bool?
    var wishlistLinks: [String]?

    func asFirestoreDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    static func fromFirestoreDictionary(_ dict: [String: Any]) throws -> ProfileDetails {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(ProfileDetails.self, from: data)
    }
}
