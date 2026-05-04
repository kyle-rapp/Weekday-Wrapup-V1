import Foundation
import FirebaseAuth
import FirebaseFirestore

/// FILE: Services/AuthManager.swift
/// Email/password auth, session persistence (Firebase SDK), and Firestore user profile.
@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var isLoggedIn = false
    @Published var authError: String?

    private var authListener: AuthStateDidChangeListenerHandle?
    /// `nil` in preview mode (no Firebase).
    private var db: Firestore?

    init() {
        db = Firestore.firestore()
        if let existing = Auth.auth().currentUser {
            isLoggedIn = true
            Task { await handleAuthState(user: existing) }
        }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                await self?.handleAuthState(user: user)
            }
        }
    }

    #if DEBUG
    /// Xcode Previews only — does not call `Auth` or Firestore.
    init(previewLoggedIn: Bool, previewUser: AppUser? = nil) {
        db = nil
        authListener = nil
        if previewLoggedIn {
            currentUser = previewUser ?? AppUser(id: "preview-user-id", name: "Alex", email: "alex@example.com")
            isLoggedIn = true
        } else {
            currentUser = nil
            isLoggedIn = false
        }
    }
    #endif

    deinit {
        if let authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }

    private func handleAuthState(user: FirebaseAuth.User?) async {
        guard let user else {
            currentUser = nil
            isLoggedIn = false
            return
        }
        isLoggedIn = true
        await loadOrSeedProfile(for: user)
    }

    private func loadOrSeedProfile(for user: FirebaseAuth.User) async {
        guard let db else { return }
        let ref = db.collection("users").document(user.uid)
        do {
            let snap = try await ref.getDocument()
            if let data = snap.data(),
               let name = data["name"] as? String,
               let email = data["email"] as? String {
                let created = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let streak = Self.intFromFirestore(data["checkInStreak"])
                let lastCheckIn = (data["lastCheckInDate"] as? Timestamp)?.dateValue()
                let postCount = Self.intFromFirestore(data["postCount"])
                let followerCount = Self.intFromFirestore(data["followerCount"])
                let followingCount = Self.intFromFirestore(data["followingCount"])
                currentUser = AppUser(
                    id: user.uid,
                    name: name,
                    email: email,
                    createdAt: created,
                    postCount: postCount,
                    followerCount: followerCount,
                    followingCount: followingCount,
                    checkInStreak: streak,
                    lastCheckInDate: lastCheckIn
                )
                if data["following"] == nil {
                    try? await ref.updateData(["following": [String]()])
                }
            } else {
                let name = user.displayName ?? "Friend"
                let email = user.email ?? ""
                let created = Date()
                try await ref.setData([
                    "name": name,
                    "email": email,
                    "createdAt": Timestamp(date: created),
                    "following": [String](),
                    "checkInStreak": 0,
                    "postCount": 0,
                    "followerCount": 0,
                    "followingCount": 0
                ], merge: true)
                currentUser = AppUser(id: user.uid, name: name, email: email, createdAt: created)
            }
        } catch {
            authError = error.localizedDescription
            let fallbackEmail = user.email ?? ""
            currentUser = AppUser(id: user.uid, name: user.displayName ?? "Friend", email: fallbackEmail)
        }
    }

    func signUp(email: String, password: String, name: String) async {
        authError = nil
        guard let db else {
            authError = "Sign up isn’t available in Xcode Previews."
            return
        }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let ref = db.collection("users").document(result.user.uid)
            let created = Date()
            try await ref.setData([
                "name": name,
                "email": email,
                "createdAt": Timestamp(date: created),
                "following": [String](),
                "checkInStreak": 0,
                "postCount": 0,
                "followerCount": 0,
                "followingCount": 0
            ], merge: true)
            let change = result.user.createProfileChangeRequest()
            change.displayName = name
            try await change.commitChanges()
            currentUser = AppUser(id: result.user.uid, name: name, email: email, createdAt: created)
            isLoggedIn = true
        } catch {
            authError = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        authError = nil
        guard db != nil else {
            authError = "Sign in isn’t available in Xcode Previews."
            return
        }
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            authError = error.localizedDescription
        }
    }

    /// Call after a wrapup is successfully posted to the feed. Updates Firestore `users` streak fields.
    func recordSuccessfulWrapupPost() async {
        guard let db, let uid = currentUser?.id, var user = currentUser else { return }
        let cal = Calendar.current
        let now = Date()
        var newStreak = user.checkInStreak
        if let last = user.lastCheckInDate {
            if cal.isDateInYesterday(last) {
                newStreak += 1
            } else if !cal.isDateInToday(last) {
                newStreak = 1
            }
        } else {
            newStreak = 1
        }
        do {
            try await db.collection("users").document(uid).updateData([
                "checkInStreak": newStreak,
                "lastCheckInDate": Timestamp(date: now)
            ])
            user.checkInStreak = newStreak
            user.lastCheckInDate = now
            currentUser = user
        } catch {
            AppLogger.error("Streak update failed: \(error.localizedDescription)")
        }
    }

    private static func intFromFirestore(_ value: Any?) -> Int {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        return 0
    }

    func signOut() async {
        authError = nil
        FirestoreManager.shared.teardownForLogout()
        guard db != nil else {
            currentUser = nil
            isLoggedIn = false
            return
        }
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isLoggedIn = false
        } catch {
            authError = error.localizedDescription
        }
    }
}
