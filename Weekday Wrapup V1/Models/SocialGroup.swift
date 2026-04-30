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
    /// Optional invites stored as email or phone strings (no auth account yet).
    var invitedContacts: [String]?
    /// When true, new members may see older group-scoped posts (client + rules must align).
    var allowHistoryAccessForNewMembers: Bool?
    var description: String?
}
