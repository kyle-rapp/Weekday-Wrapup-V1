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
    /// Presented above the scroll view so the dimming layer isn’t clipped.
    @State private var expandedReactionPostId: String?
    @State private var feedPresentCreateGroup = false

    private var myHistoryEntries: [CheckInData] {
        firestore.wrapupHistoryEntries(forUserId: auth.currentUser?.id)
    }

    private var palettePost: FeedPost? {
        guard let id = expandedReactionPostId else { return nil }
        return firestore.posts.first(where: { $0.id == id })
    }

    private var paletteViewerId: String? { auth.currentUser?.id }

    var body: some View {
        ZStack {
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
                            FeedPostCard(post: post, expandedReactionPostId: $expandedReactionPostId)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    feedViewModel.openPost(post)
                                }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 22)
            }

            if palettePost != nil {
                feedReactionPaletteOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: expandedReactionPostId)
        .background(feedBackground.ignoresSafeArea())
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if auth.currentUser != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 18) {
                        NavigationLink {
                            GroupsView()
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "person.3.sequence.fill")
                                    .font(.body.weight(.semibold))
                                Text("Groups")
                                    .font(.caption2)
                                    .foregroundStyle(.primary)
                                    .opacity(0.9)
                            }
                            .foregroundStyle(.primary)
                            .frame(minWidth: 48)
                        }
                        .contextMenu {
                            Button {
                                feedPresentCreateGroup = true
                            } label: {
                                Label("Create Group", systemImage: "plus.circle")
                            }
                        }
                        .accessibilityLabel("Groups")

                        NavigationLink {
                            HistoryView(entries: myHistoryEntries)
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.colors.ocean)
                        }
                        .accessibilityLabel("Past wrapups")
                    }
                }
            }
        }
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
        .sheet(isPresented: $feedPresentCreateGroup) {
            NavigationStack {
                CreateGroupView()
            }
            .environmentObject(firestore)
            .environmentObject(auth)
        }
    }

    @ViewBuilder
    private var feedReactionPaletteOverlay: some View {
        if let p = palettePost {
            ZStack {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        expandedReactionPostId = nil
                    }

                VStack {
                    Spacer()
                    ExpandedReactionPalette(
                        reactionCounts: p.reactions,
                        selectedEmoji: p.reactionForCurrentUser(paletteViewerId),
                        onPick: { emoji in
                            guard let uid = paletteViewerId else { return }
                            Task { @MainActor in
                                do {
                                    try await firestore.applyReaction(postId: p.id, userId: uid, emoji: emoji)
                                    expandedReactionPostId = nil
                                } catch {
                                    print("❌ Reaction failed: \(error.localizedDescription)")
                                }
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

// MARK: - Card

struct FeedPostCard: View {
    let post: FeedPost
    @Binding var expandedReactionPostId: String?
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var feedViewModel: FeedViewModel

    private var uid: String? { auth.currentUser?.id }
    private var livePost: FeedPost {
        firestore.posts.first(where: { $0.id == post.id }) ?? post
    }
    private var isFollowingAuthor: Bool {
        firestore.isFollowing(livePost.authorId)
    }

    var body: some View {
        cardBody
            .onLongPressGesture(minimumDuration: 0.45, pressing: nil) {
                guard uid != nil else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                expandedReactionPostId = post.id
            }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.orange.opacity(0.85))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        NavigationLink {
                            ProfileView(userId: livePost.authorId, contextPost: livePost)
                                .environmentObject(firestore)
                                .environmentObject(auth)
                        } label: {
                            Text(livePost.user.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 8)
                        if let uid, uid != livePost.authorId {
                            Button {
                                Task {
                                    await feedViewModel.toggleFollow(authorId: livePost.authorId, currentUserId: uid)
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
                    Text("🔥 \(livePost.user.streak) week streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text(livePost.visibility.rawValue)
                            .font(.caption2)
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(RelativeTimeFormat.string(for: livePost.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.secondary.opacity(0.95))
                }
            }

            HStack(spacing: 10) {
                Text(livePost.emoji)
                    .font(.system(size: 40))
                Text("Week wrapup")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 8) {
                let label = livePost.primaryEmotionDisplayLabel
                if !label.isEmpty {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Capsule())
                }
                if let intensity = livePost.intensity {
                    Text("Intensity \(intensity)/10")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if !livePost.whoop.isEmpty {
                Text("Whoops: \(livePost.whoop)")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.9))
            }
            if !livePost.goal.isEmpty {
                Text("Goal: \(livePost.goal)")
                    .font(.caption)
                    .foregroundStyle(.blue.opacity(0.9))
            }

            FeedReactionRow(
                livePost: livePost,
                uid: uid,
                onOpenPalette: { expandedReactionPostId = post.id }
            )

            HStack(spacing: 22) {
                Button {
                    guard let uid else { return }
                    Task { @MainActor in
                        do {
                            try await firestore.toggleLike(postId: livePost.id, userId: uid)
                        } catch {
                            print("❌ Like failed: \(error.localizedDescription)")
                        }
                    }
                } label: {
                    Label("\(livePost.likeCount)", systemImage: livePost.isLikedByCurrentUser(uid) ? "heart.fill" : "heart")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(livePost.isLikedByCurrentUser(uid) ? .pink : .secondary)
                }
                .buttonStyle(.borderless)
                .disabled(uid == nil)
                .scaleEffect(livePost.isLikedByCurrentUser(uid) ? 1.14 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: livePost.isLikedByCurrentUser(uid))

                Label("\(livePost.commentCount)", systemImage: "bubble.right.fill")
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
    @State private var expandedReactionPostId: String?

    var body: some View {
        ScrollView {
            FeedPostCard(post: PreviewSampleData.sampleFeedPosts[0], expandedReactionPostId: $expandedReactionPostId)
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
