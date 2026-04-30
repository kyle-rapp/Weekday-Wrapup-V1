import Foundation

/// FILE: Models/UserProfile.swift
/// Stored at `users/{userId}/profile/main` (merge-friendly; optional fields for older clients).

struct UserProfile: Codable, Equatable, Hashable {
    var name: String
    var bio: String?
    var location: String?
    var school: String?

    var joys: [String]
    var interests: [String]

    var wishlistLinks: [String]

    var isOpenToMeetups: Bool?
    var prefersSupport: [String]?

    init(
        name: String,
        bio: String? = nil,
        location: String? = nil,
        school: String? = nil,
        joys: [String] = [],
        interests: [String] = [],
        wishlistLinks: [String] = [],
        isOpenToMeetups: Bool? = nil,
        prefersSupport: [String]? = nil
    ) {
        self.name = name
        self.bio = bio
        self.location = location
        self.school = school
        self.joys = joys
        self.interests = interests
        self.wishlistLinks = wishlistLinks
        self.isOpenToMeetups = isOpenToMeetups
        self.prefersSupport = prefersSupport
    }

    func asFirestoreDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    static func fromFirestoreDictionary(_ dict: [String: Any]) throws -> UserProfile {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }
}
