import Foundation

/// FILE: Models/UserProfile.swift
/// Document `users/{userId}/profile/main` (merge writes). Flat fields stay Firestore-friendly.

struct UserProfileSupportPreferences: Codable, Equatable, Hashable {
    var allowContact: Bool?
    var contactMethods: [String]?
    var phoneNumber: String?
    var email: String?
    /// When true, prefer in-app reach-outs over sharing raw contact info (UX hint).
    var appUsersOnly: Bool?
}

struct UserProfile: Codable, Equatable, Hashable {
    var name: String?
    var zodiacSign: String?
    var bio: String?
    var profileImageURL: String?
    var hasProfileImage: Bool?
    var location: String?
    var school: String?
    var pronouns: String?
    var pets: String?
    var drinkingPreference: String?
    var relationshipStatus: String?

    var supportPreferences: UserProfileSupportPreferences?

    /// “Things I like” (product copy: interests / likes).
    var interests: [String]?
    var joys: [String]?
    /// Future-ready explicit public shares; never auto-copied from private Dopamine Menu.
    var publicJoyItems: [String]?
    var publicLikeItems: [String]?
    var wishlistLinks: [String]?

    var isOpenToMeetups: Bool?
    var prefersSupport: [String]?

    /// Soundtrack for the season — optional, shown on profile.
    var favoriteSong: String?
    var favoriteArtist: String?
    var venmoUsername: String?
    var showFavoriteSong: Bool?
    var showVenmoUsername: Bool?
    /// `Public` / `Friends` / `Private` — client-side gating for sensitive sections.
    var profileVisibility: String?

    init(
        name: String? = nil,
        zodiacSign: String? = nil,
        bio: String? = nil,
        profileImageURL: String? = nil,
        hasProfileImage: Bool? = nil,
        location: String? = nil,
        school: String? = nil,
        pronouns: String? = nil,
        pets: String? = nil,
        drinkingPreference: String? = nil,
        relationshipStatus: String? = nil,
        supportPreferences: UserProfileSupportPreferences? = nil,
        interests: [String]? = nil,
        joys: [String]? = nil,
        publicJoyItems: [String]? = nil,
        publicLikeItems: [String]? = nil,
        wishlistLinks: [String]? = nil,
        isOpenToMeetups: Bool? = nil,
        prefersSupport: [String]? = nil,
        favoriteSong: String? = nil,
        favoriteArtist: String? = nil,
        venmoUsername: String? = nil,
        showFavoriteSong: Bool? = nil,
        showVenmoUsername: Bool? = nil,
        profileVisibility: String? = nil
    ) {
        self.name = name
        self.zodiacSign = zodiacSign
        self.bio = bio
        self.profileImageURL = profileImageURL
        self.hasProfileImage = hasProfileImage
        self.location = location
        self.school = school
        self.pronouns = pronouns
        self.pets = pets
        self.drinkingPreference = drinkingPreference
        self.relationshipStatus = relationshipStatus
        self.supportPreferences = supportPreferences
        self.interests = interests
        self.joys = joys
        self.publicJoyItems = publicJoyItems
        self.publicLikeItems = publicLikeItems
        self.wishlistLinks = wishlistLinks
        self.isOpenToMeetups = isOpenToMeetups
        self.prefersSupport = prefersSupport
        self.favoriteSong = favoriteSong
        self.favoriteArtist = favoriteArtist
        self.venmoUsername = venmoUsername
        self.showFavoriteSong = showFavoriteSong
        self.showVenmoUsername = showVenmoUsername
        self.profileVisibility = profileVisibility
    }

    func asFirestoreDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    static func fromFirestoreDictionary(_ dict: [String: Any]) throws -> UserProfile {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [])
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }
}
