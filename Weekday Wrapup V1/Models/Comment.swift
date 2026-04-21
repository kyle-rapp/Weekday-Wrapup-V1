import Foundation
import FirebaseFirestore

/// FILE: Models/Comment.swift
/// Maps `posts/{postId}/comments/{commentId}` documents.

struct Comment: Identifiable, Equatable, Hashable {
    let id: String
    let userId: String
    let userName: String
    let text: String
    let createdAt: Date?

    init(id: String, userId: String, userName: String, text: String, createdAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.text = text
        self.createdAt = createdAt
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        guard let userId = data["userId"] as? String,
              let userName = data["userName"] as? String,
              let text = data["text"] as? String else { return nil }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        self.id = document.documentID
        self.userId = userId
        self.userName = userName
        self.text = text
        self.createdAt = createdAt
    }
}
