import Foundation

/// FILE: Models/AppUser.swift
/// App user profile (backed by Firebase Auth + Firestore `users` collection).
struct AppUser: Identifiable, Equatable {
    let id: String
    var name: String
    var email: String
    var createdAt: Date

    init(id: String, name: String, email: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
    }
}
