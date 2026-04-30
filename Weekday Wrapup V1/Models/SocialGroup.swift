import Foundation

/// FILE: Models/SocialGroup.swift
/// A small circle for scoped feed sharing (`groups` collection).
/// Named `SocialGroup` to avoid clashing with `SwiftUI.Group`.

struct SocialGroup: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    /// Firebase Auth user ids in this group.
    var memberIds: [String]
    var createdBy: String
    /// Admins may manage members in-app when rules allow (defaults to owner).
    var adminIds: [String]
    var createdAt: Date?
    /// Optional invites stored as email or phone strings (no auth account yet).
    var invitedContacts: [String]?
    /// When true, new members may see older group-scoped posts (client + rules must align).
    var allowHistoryAccessForNewMembers: Bool?
    var description: String?

    init(
        id: String,
        name: String,
        memberIds: [String],
        createdBy: String,
        adminIds: [String]? = nil,
        createdAt: Date? = nil,
        invitedContacts: [String]? = nil,
        allowHistoryAccessForNewMembers: Bool? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.memberIds = memberIds
        self.createdBy = createdBy
        self.adminIds = adminIds ?? [createdBy]
        self.createdAt = createdAt
        self.invitedContacts = invitedContacts
        self.allowHistoryAccessForNewMembers = allowHistoryAccessForNewMembers
        self.description = description
    }
}

extension SocialGroup {
    /// Alias for `memberIds` (matches product “members” language).
    var members: [String] { memberIds }
}
