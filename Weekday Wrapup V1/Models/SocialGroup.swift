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
    /// Per-member override: uid → may see past group-scoped content (set when they join).
    var memberHistoryAccess: [String: Bool]?
    var description: String?
    /// Search keywords and support themes (e.g. ["anxiety", "burnout"]).
    var tags: [String]
    /// Extra alias terms used for discoverability/ranking.
    var searchKeywords: [String]
    /// Primary mental health category (e.g. "anxiety", "ADHD", "grief").
    var category: String?

    init(
        id: String,
        name: String,
        memberIds: [String],
        createdBy: String,
        adminIds: [String]? = nil,
        createdAt: Date? = nil,
        invitedContacts: [String]? = nil,
        allowHistoryAccessForNewMembers: Bool? = nil,
        memberHistoryAccess: [String: Bool]? = nil,
        description: String? = nil,
        tags: [String] = [],
        searchKeywords: [String] = [],
        category: String? = nil
    ) {
        self.id = id
        self.name = name
        self.memberIds = memberIds
        self.createdBy = createdBy
        self.adminIds = adminIds ?? [createdBy]
        self.createdAt = createdAt
        self.invitedContacts = invitedContacts
        self.allowHistoryAccessForNewMembers = allowHistoryAccessForNewMembers
        self.memberHistoryAccess = memberHistoryAccess
        self.description = description
        self.tags = tags
        self.searchKeywords = searchKeywords
        self.category = category
    }
}

extension SocialGroup {
    /// Alias for `memberIds` (matches product “members” language).
    var members: [String] { memberIds }
}
