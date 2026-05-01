import Foundation

/// FILE: Models/SupportSettings.swift
/// Private support controls at `users/{uid}/support/settings`.

enum SupportMode: String, Codable, CaseIterable {
    case open
    case friendsOnly
    case privateMode
}

enum SupportVisibility: String, Codable, CaseIterable {
    case `public`
    case friends
    case privateMode
}

struct SupportSettings: Codable, Equatable, Hashable {
    var allowSupport: Bool
    var supportMode: SupportMode
    var isSupportTodayEnabled: Bool
    var supportExpiresAt: Date?
    var visibility: SupportVisibility
    var allowMessages: Bool
    var allowInvites: Bool
    var allowGifts: Bool

    init(
        allowSupport: Bool = true,
        supportMode: SupportMode = .friendsOnly,
        isSupportTodayEnabled: Bool = false,
        supportExpiresAt: Date? = nil,
        visibility: SupportVisibility = .friends,
        allowMessages: Bool = false,
        allowInvites: Bool = true,
        allowGifts: Bool = false
    ) {
        self.allowSupport = allowSupport
        self.supportMode = supportMode
        self.isSupportTodayEnabled = isSupportTodayEnabled
        self.supportExpiresAt = supportExpiresAt
        self.visibility = visibility
        self.allowMessages = allowMessages
        self.allowInvites = allowInvites
        self.allowGifts = allowGifts
    }

    func asFirestoreDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    static func fromFirestoreDictionary(_ dict: [String: Any]) throws -> SupportSettings {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(SupportSettings.self, from: data)
    }

    var isTemporarilyActiveNow: Bool {
        guard isSupportTodayEnabled else { return false }
        guard let supportExpiresAt else { return true }
        return Date() <= supportExpiresAt
    }

    var isExpiredNow: Bool {
        guard isSupportTodayEnabled, let supportExpiresAt else { return false }
        return Date() > supportExpiresAt
    }
}

