import Foundation

/// FILE: Managers/ProfileManager.swift
/// Caches `UserProfile` loads by user id; coordinates with `FirestoreManager`.

@MainActor
final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    private let firestore: FirestoreManager
    private var cache: [String: UserProfile] = [:]

    init(firestore: FirestoreManager = .shared) {
        self.firestore = firestore
    }

    func cachedProfile(userId: String) -> UserProfile? {
        cache[userId]
    }

    func loadProfile(userId: String, forceRefresh: Bool = false) async -> UserProfile? {
        if !forceRefresh, let hit = cache[userId] { return hit }
        let p = await firestore.fetchUserProfile(userId: userId)
        if let p { cache[userId] = p }
        return p
    }

    func saveProfile(_ profile: UserProfile, userId: String) async throws {
        try await firestore.saveUserProfile(profile, userId: userId)
        cache[userId] = profile
    }

    func invalidate(userId: String) {
        cache.removeValue(forKey: userId)
    }
}
