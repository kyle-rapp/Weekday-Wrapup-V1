import SwiftUI

/// FILE: Views/PostDetailView.swift
/// Full post + reactions + likes + live comments (`posts/{id}/comments`).

private let detailBackground = Color(red: 0.99, green: 0.97, blue: 0.94)

struct PostDetailView: View {
    let post: FeedPost
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @State private var newComment = ""
    @State private var isPostingComment = false
    @State private var showErrorAlert = false
    @State private var alertMessage = ""

    private var uid: String? { auth.currentUser?.id }
    private var livePost: FeedPost {
        firestore.posts.first(where: { $0.id == post.id }) ?? post
    }

    private var isFollowingAuthor: Bool {
        firestore.isFollowing(livePost.authorId)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerRow

                HStack(spacing: 10) {
                    Text(livePost.emoji)
                        .font(.system(size: 52))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Week wrapup")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(RelativeTimeFormat.string(for: livePost.createdAt))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }

                Text(livePost.insight)
                    .font(.body)

                if !livePost.whoop.isEmpty {
                    Text("Whoops: \(livePost.whoop)")
                        .foregroundStyle(.orange)
                }
                if !livePost.goal.isEmpty {
                    Text("Weekly goal: \(livePost.goal)")
                        .foregroundStyle(.blue)
                }

                reactionRowDetail

                HStack(spacing: 20) {
                    Button {
                        guard let uid else { return }
                        Task { @MainActor in
                            do {
                                try await firestore.toggleLike(postId: livePost.id, userId: uid)
                            } catch {
                                print("❌ Like failed: \(error.localizedDescription)")
                                presentAlert(error.localizedDescription)
                                firestore.clearErrorMessage()
                            }
                        }
                    } label: {
                        Label("\(livePost.likeCount) Like\(livePost.likeCount == 1 ? "" : "s")", systemImage: livePost.isLikedByCurrentUser(uid) ? "heart.fill" : "heart")
                            .foregroundStyle(livePost.isLikedByCurrentUser(uid) ? .pink : .primary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(uid == nil)
                    .scaleEffect(livePost.isLikedByCurrentUser(uid) ? 1.12 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.62), value: livePost.isLikedByCurrentUser(uid))

                    Label("\(livePost.commentCount) Comment\(livePost.commentCount == 1 ? "" : "s")", systemImage: "bubble.right.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                Divider()
                    .padding(.vertical, 4)

                Text("Comments")
                    .font(.title3.bold())

                if firestore.detailComments.isEmpty {
                    Text("No comments yet—be the first to say something kind.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(firestore.detailComments) { comment in
                            commentRow(comment)
                                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: firestore.detailComments.count)
                }

                commentComposer
            }
            .padding(22)
        }
        .background(detailBackground.ignoresSafeArea())
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            firestore.startCommentsListener(postId: post.id)
        }
        .onDisappear {
            firestore.stopCommentsListener()
        }
        .alert("Something went wrong", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                showErrorAlert = false
            }
        } message: {
            Text(alertMessage)
        }
    }

    private func presentAlert(_ message: String) {
        alertMessage = message
        showErrorAlert = true
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 56, height: 56)
                .foregroundStyle(.orange.opacity(0.88))
            VStack(alignment: .leading, spacing: 6) {
                Text(livePost.user.name)
                    .font(.title2.bold())
                Text("🔥 \(livePost.user.streak) week streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                    Text(livePost.visibility.rawValue)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            if let uid, uid != livePost.authorId {
                Button {
                    Task { @MainActor in
                        await feedViewModel.toggleFollow(authorId: livePost.authorId, currentUserId: uid)
                        if let msg = firestore.errorMessage, !msg.isEmpty {
                            presentAlert(msg)
                            firestore.clearErrorMessage()
                        }
                    }
                } label: {
                    Text(isFollowingAuthor ? "Following" : "Follow")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isFollowingAuthor ? Color.green.opacity(0.18) : Color.blue.opacity(0.15))
                        .foregroundStyle(isFollowingAuthor ? .green : .blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
                .animation(.easeInOut(duration: 0.2), value: isFollowingAuthor)
            }
        }
    }

    private func commentRow(_ comment: Comment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comment.userName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(RelativeTimeFormat.string(for: comment.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(comment.text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.orange.opacity(0.08)))
    }

    private var commentComposer: some View {
        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let canPost = !trimmed.isEmpty && uid != nil && !isPostingComment

        return HStack(alignment: .bottom, spacing: 10) {
            TextField("Add a comment...", text: $newComment, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button("Post") {
                guard let uid, let name = auth.currentUser?.name else { return }
                Task { @MainActor in
                    isPostingComment = true
                    defer { isPostingComment = false }
                    do {
                        try await firestore.addComment(postId: livePost.id, userId: uid, userName: name, text: newComment)
                        newComment = ""
                    } catch {
                        print("❌ Comment failed: \(error.localizedDescription)")
                        presentAlert(error.localizedDescription)
                        firestore.clearErrorMessage()
                    }
                }
            }
            .font(.body.weight(.semibold))
            .disabled(!canPost)
        }
        .padding(.top, 8)
    }

    private var reactionRowDetail: some View {
        HStack(spacing: 12) {
            ForEach(Array(livePost.reactions.keys.sorted()), id: \.self) { key in
                Button {
                    guard let uid else { return }
                    Task { @MainActor in
                        do {
                            try await firestore.applyReaction(postId: livePost.id, userId: uid, emoji: key)
                        } catch {
                            print("❌ Reaction failed: \(error.localizedDescription)")
                            presentAlert(error.localizedDescription)
                            firestore.clearErrorMessage()
                        }
                    }
                } label: {
                    Text("\(key) \(livePost.reactions[key, default: 0])")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(livePost.reactionForCurrentUser(uid) == key ? Color.accentColor.opacity(0.22) : Color.orange.opacity(0.12))
                        )
                        .overlay(
                            Capsule()
                                .stroke(livePost.reactionForCurrentUser(uid) == key ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.borderless)
                .disabled(uid == nil)
                .scaleEffect(livePost.reactionForCurrentUser(uid) == key ? 1.05 : 1.0)
                .animation(.spring(response: 0.32, dampingFraction: 0.68), value: livePost.reactionForCurrentUser(uid))
            }
        }
    }
}
