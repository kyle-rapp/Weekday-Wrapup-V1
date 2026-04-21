import SwiftUI

/// FILE: ViewModels/FeedViewModel.swift
/// Lightweight feed navigation + social actions (Firestore stays in FirestoreManager).

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var path = NavigationPath()

    private let firestore: FirestoreManager

    init(firestore: FirestoreManager = .shared) {
        self.firestore = firestore
    }

    func openPost(_ post: FeedPost) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            path.append(post)
        }
    }

    func toggleFollow(authorId: String, currentUserId: String?) async {
        guard let currentUserId, currentUserId != authorId else { return }
        let shouldFollow = !firestore.isFollowing(authorId)
        do {
            try await firestore.setFollowing(currentUserId: currentUserId, targetUserId: authorId, follow: shouldFollow)
        } catch {
            print("❌ Follow action failed: \(error.localizedDescription)")
            // `errorMessage` is set inside FirestoreManager for most failures.
        }
    }
}
