import Foundation
import FirebaseFirestore

/// FILE: Models/SupportInboxItem.swift
/// Incoming support actions stored in `users/{uid}/supportInbox`.

enum SupportInboxType: String, Codable, CaseIterable {
    case message
    case invite
    case gift
}

struct SupportInboxItem: Identifiable, Equatable, Hashable {
    let id: String
    let fromUserId: String
    let type: SupportInboxType
    let text: String?
    let activity: String?
    let itemTitle: String?
    let itemURL: String?
    let createdAt: Date?

    init?(_ doc: DocumentSnapshot) {
        guard let data = doc.data(),
              let fromUserId = data["fromUserId"] as? String,
              let typeRaw = data["type"] as? String,
              let type = SupportInboxType(rawValue: typeRaw) else { return nil }
        self.id = doc.documentID
        self.fromUserId = fromUserId
        self.type = type
        self.text = data["text"] as? String
        self.activity = data["activity"] as? String
        self.itemTitle = data["itemTitle"] as? String
        self.itemURL = data["itemURL"] as? String
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
    }
}

