import SwiftUI
import UIKit

/// FILE: ViewModels/FeedViewModel.swift
/// Lightweight feed navigation + social actions (Firestore stays in FirestoreManager).

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var path = NavigationPath()
    /// When set, the post detail composer replies to this comment (any depth; `parentCommentId` is the comment’s id).
    @Published var replyTarget: Comment?

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

    func setReplyTarget(_ comment: Comment) {
        replyTarget = comment
    }

    func clearReplyTarget() {
        replyTarget = nil
    }

    func toggleLikeComment(postId: String, comment: Comment, currentUserId: String?) async {
        guard let currentUserId else { return }
        let addingLike = !comment.likedBy.contains(currentUserId)
        do {
            try await firestore.toggleCommentLike(postId: postId, comment: comment, userId: currentUserId)
            if addingLike, comment.userId != currentUserId {
                print("User liked your comment")
            }
        } catch {
            print("❌ Comment like failed: \(error.localizedDescription)")
        }
    }

    func addReply(postId: String, parentId: String, text: String, userId: String, userName: String) async throws {
        try await firestore.addReplyComment(
            postId: postId,
            parentCommentId: parentId,
            userId: userId,
            userName: userName,
            text: text
        )
    }

    func incrementCommentReaction(postId: String, comment: Comment, emoji: String, currentUserId: String?) async {
        guard let currentUserId else { return }
        do {
            try await firestore.incrementCommentReaction(
                postId: postId,
                comment: comment,
                emoji: emoji,
                userId: currentUserId
            )
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            print("❌ Comment reaction failed: \(error.localizedDescription)")
        }
    }
}
