import Foundation
import FirebaseFirestore

/// FILE: Models/Conversation.swift
/// 1:1 or group direct-message thread stored in Firestore.

struct Conversation: Identifiable, Hashable {
    let id: String
    let participantIds: [String]
    let lastMessage: String?
    let lastSenderId: String?
    let updatedAt: Date?

    /// Display name for the other participant (resolved at the call site from `AppUser` data).
    var otherParticipantName: String?

    init(id: String, participantIds: [String], lastMessage: String? = nil,
         lastSenderId: String? = nil, updatedAt: Date? = nil,
         otherParticipantName: String? = nil) {
        self.id = id
        self.participantIds = participantIds
        self.lastMessage = lastMessage
        self.lastSenderId = lastSenderId
        self.updatedAt = updatedAt
        self.otherParticipantName = otherParticipantName
    }

    init?(document: DocumentSnapshot, myUserId: String) {
        guard let data = document.data() else { return nil }
        let ids = data["participantIds"] as? [String] ?? []
        self.id = document.documentID
        self.participantIds = ids
        self.lastMessage = data["lastMessage"] as? String
        self.lastSenderId = data["lastSenderId"] as? String
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        self.otherParticipantName = nil
    }

    func otherUserId(myId: String) -> String? {
        participantIds.first(where: { $0 != myId })
    }
}

struct DirectMessage: Identifiable, Hashable {
    let id: String
    let conversationId: String
    let senderId: String
    let recipientId: String?
    let text: String
    let type: String
    let systemTone: String?
    let read: Bool?
    let createdAt: Date?

    var isThinkingOfYou: Bool {
        type == "thinkingOfYou"
    }

    init(
        id: String,
        conversationId: String,
        senderId: String,
        recipientId: String? = nil,
        text: String,
        type: String = "text",
        systemTone: String? = nil,
        read: Bool? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.recipientId = recipientId
        self.text = text
        self.type = type
        self.systemTone = systemTone
        self.read = read
        self.createdAt = createdAt
    }

    init?(document: DocumentSnapshot, conversationId: String) {
        guard let data = document.data(),
              let senderId = data["senderId"] as? String,
              let text = data["text"] as? String else { return nil }
        self.id = document.documentID
        self.conversationId = conversationId
        self.senderId = senderId
        self.recipientId = data["recipientId"] as? String
        self.text = text
        self.type = data["type"] as? String ?? "text"
        self.systemTone = data["systemTone"] as? String
        self.read = data["read"] as? Bool
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
    }
}
