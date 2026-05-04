import Foundation

/// FILE: Models/AppUser.swift
/// App user profile (backed by Firebase Auth + Firestore `users` collection).
struct AppUser: Identifiable, Equatable {
    let id: String
    var name: String
    var email: String
    var createdAt: Date
    var postCount: Int
    var followerCount: Int
    var followingCount: Int
    /// Consecutive days with at least one wrapup post to the feed (see `AuthManager.recordSuccessfulWrapupPost`).
    var checkInStreak: Int
    /// Last calendar day a wrapup was posted (server-updated when a feed post succeeds).
    var lastCheckInDate: Date?

    init(
        id: String,
        name: String,
        email: String,
        createdAt: Date = Date(),
        postCount: Int = 0,
        followerCount: Int = 0,
        followingCount: Int = 0,
        checkInStreak: Int = 0,
        lastCheckInDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
        self.postCount = postCount
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.checkInStreak = checkInStreak
        self.lastCheckInDate = lastCheckInDate
    }
}
