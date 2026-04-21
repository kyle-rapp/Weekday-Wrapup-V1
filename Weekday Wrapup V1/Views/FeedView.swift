import SwiftUI

/// FILE: Views/FeedView.swift
/// Real-time feed UI + navigation to `PostDetailView`.

private let feedBackground = Color(red: 0.99, green: 0.97, blue: 0.94)
private let feedCardShadow = Color.brown.opacity(0.12)

struct FeedView: View {
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager
    @State private var showFirestoreAlert = false
    @State private var firestoreAlertText = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                if firestore.posts.isEmpty {
                    Text("No posts yet. Share a wrapup from the Share tab!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 48)
                        .padding(.horizontal)
                } else {
                    ForEach(firestore.posts) { post in
                        Button {
                            feedViewModel.openPost(post)
                        } label: {
                            FeedPostCard(post: post)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
        }
        .background(feedBackground.ignoresSafeArea())
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .onChange(of: firestore.errorMessage) { _, message in
            guard let message, !message.isEmpty else { return }
            firestoreAlertText = message
            showFirestoreAlert = true
            firestore.clearErrorMessage()
        }
        .alert("Something went wrong", isPresented: $showFirestoreAlert) {
            Button("OK", role: .cancel) {
                showFirestoreAlert = false
            }
        } message: {
            Text(firestoreAlertText)
        }
    }
}

// MARK: - Card

struct FeedPostCard: View {
    let post: FeedPost
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var feedViewModel: FeedViewModel

    private var uid: String? { auth.currentUser?.id }
    private var isFollowingAuthor: Bool {
        firestore.isFollowing(post.authorId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.orange.opacity(0.85))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(post.user.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        if let uid, uid != post.authorId {
                            Button {
                                Task {
                                    await feedViewModel.toggleFollow(authorId: post.authorId, currentUserId: uid)
                                }
                            } label: {
                                Text(isFollowingAuthor ? "Following" : "Follow")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isFollowingAuthor ? Color.green.opacity(0.16) : Color.blue.opacity(0.12))
                                    .foregroundStyle(isFollowingAuthor ? .green : .blue)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.borderless)
                            .animation(.easeInOut(duration: 0.2), value: isFollowingAuthor)
                        }
                    }
                    Text("🔥 \(post.user.streak) week streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text(post.visibility.rawValue)
                            .font(.caption2)
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(RelativeTimeFormat.string(for: post.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.secondary.opacity(0.95))
                }
            }

            HStack(spacing: 10) {
                Text(post.emoji)
                    .font(.system(size: 40))
                Text("Week wrapup")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(post.insight)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if !post.whoop.isEmpty {
                Text("Whoops: \(post.whoop)")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.9))
            }
            if !post.goal.isEmpty {
                Text("Goal: \(post.goal)")
                    .font(.caption)
                    .foregroundStyle(.blue.opacity(0.9))
            }

            reactionRow

            HStack(spacing: 22) {
                Button {
                    guard let uid else { return }
                    Task { @MainActor in
                        do {
                            try await firestore.toggleLike(postId: post.id, userId: uid)
                        } catch {
                            print("❌ Like failed: \(error.localizedDescription)")
                        }
                    }
                } label: {
                    Label("\(post.likeCount)", systemImage: post.isLikedByCurrentUser(uid) ? "heart.fill" : "heart")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(post.isLikedByCurrentUser(uid) ? .pink : .secondary)
                }
                .buttonStyle(.borderless)
                .disabled(uid == nil)
                .scaleEffect(post.isLikedByCurrentUser(uid) ? 1.14 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: post.isLikedByCurrentUser(uid))

                Label("\(post.commentCount)", systemImage: "bubble.right.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: feedCardShadow, radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.orange.opacity(0.08), lineWidth: 1)
        )
    }

    private var reactionRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(post.reactions.keys.sorted()), id: \.self) { key in
                Button {
                    guard let uid else { return }
                    Task { @MainActor in
                        do {
                            try await firestore.applyReaction(postId: post.id, userId: uid, emoji: key)
                        } catch {
                            print("❌ Reaction failed: \(error.localizedDescription)")
                        }
                    }
                } label: {
                    Text("\(key) \(post.reactions[key, default: 0])")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(post.reactionForCurrentUser(uid) == key ? Color.accentColor.opacity(0.2) : Color.orange.opacity(0.1))
                        )
                        .overlay(
                            Capsule()
                                .stroke(post.reactionForCurrentUser(uid) == key ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.borderless)
                .disabled(uid == nil)
                .scaleEffect(post.reactionForCurrentUser(uid) == key ? 1.06 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: post.reactionForCurrentUser(uid))
            }
        }
    }
}

#if DEBUG
private struct FeedPreviewHost: View {
    @StateObject private var auth = AuthManager(previewLoggedIn: true, previewUser: PreviewSampleData.currentUser)
    @StateObject private var feedViewModel = FeedViewModel()
    private let firestore = FirestoreManager.shared

    var body: some View {
        NavigationStack(path: $feedViewModel.path) {
            FeedView()
                .navigationDestination(for: FeedPost.self) { post in
                    PostDetailView(post: post)
                }
        }
        .environmentObject(auth)
        .environmentObject(firestore)
        .environmentObject(feedViewModel)
        .onAppear {
            firestore.applyPreviewPosts(PreviewSampleData.sampleFeedPosts)
            firestore.applyPreviewFollowing(["user-alice"])
            firestore.applyPreviewComments(PreviewSampleData.sampleComments)
        }
    }
}

private struct FeedPostCardPreviewHost: View {
    @StateObject private var auth = AuthManager(previewLoggedIn: true, previewUser: PreviewSampleData.currentUser)
    @StateObject private var feedViewModel = FeedViewModel()
    private let firestore = FirestoreManager.shared

    var body: some View {
        ScrollView {
            FeedPostCard(post: PreviewSampleData.sampleFeedPosts[0])
                .environmentObject(auth)
                .environmentObject(firestore)
                .environmentObject(feedViewModel)
        }
        .background(feedBackground)
        .onAppear {
            firestore.applyPreviewPosts(PreviewSampleData.sampleFeedPosts)
            firestore.applyPreviewFollowing([])
        }
    }
}

private struct PostDetailPreviewHost: View {
    @StateObject private var auth = AuthManager(previewLoggedIn: true, previewUser: PreviewSampleData.currentUser)
    @StateObject private var feedViewModel = FeedViewModel()
    private let firestore = FirestoreManager.shared

    var body: some View {
        NavigationStack {
            PostDetailView(post: PreviewSampleData.sampleFeedPosts[0])
        }
        .environmentObject(auth)
        .environmentObject(firestore)
        .environmentObject(feedViewModel)
        .onAppear {
            firestore.applyPreviewPosts(PreviewSampleData.sampleFeedPosts)
            firestore.applyPreviewComments(PreviewSampleData.sampleComments)
        }
    }
}

#Preview("Feed") {
    FeedPreviewHost()
}

#Preview("Post card") {
    FeedPostCardPreviewHost()
}

#Preview("Post detail") {
    PostDetailPreviewHost()
}
#endif
