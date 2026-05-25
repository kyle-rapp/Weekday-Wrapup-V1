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
    @State private var lastFirestoreAlertText = ""
    /// Presented above the scroll view so the dimming layer isn’t clipped.
    @State private var expandedReactionPostId: String?
    @State private var feedPresentCreateGroup = false
    @State private var cachedSoftSocialNudgeLine: String?
    @State private var cachedWeeklyHelpfulTagsLine: String?
    @State private var feedSummarySignature = ""

    private var palettePost: FeedPost? {
        guard let id = expandedReactionPostId else { return nil }
        return firestore.posts.first(where: { $0.id == id })
    }

    private var paletteViewerId: String? { auth.currentUser?.id }

    private var softSocialNudgeLine: String? {
        let tough = firestore.posts.filter { post in
            guard firestore.followingIds.contains(post.authorId) else { return false }
            let emotion = post.primaryEmotion.lowercased()
            return (post.intensity ?? 0) >= 7
                || ["sad", "anxious", "overwhelmed", "lonely"].contains(where: { emotion.contains($0) })
        }
        if tough.count >= 3 {
            return "3 friends felt overwhelmed this week."
        }
        if tough.count >= 1 {
            return "Someone close to you had a tough day."
        }
        return nil
    }

    private var weeklyHelpfulTagsLine: String? {
        let topTags = firestore.topHelpfulTagsThisWeek()
        guard !topTags.isEmpty else { return nil }
        return "Most helpful this week: \(topTags.joined(separator: ", "))"
    }

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    if let nudge = cachedSoftSocialNudgeLine {
                        Text(nudge)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppTheme.colors.mist.opacity(0.35))
                            )
                    }

                    if let line = cachedWeeklyHelpfulTagsLine {
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                    }

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
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: expandedReactionPostId)
        .background(feedBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if auth.currentUser != nil {
                ToolbarItem(placement: .principal) {
                    HStack {
                        NavigationLink {
                            FindFriendsView()
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Friends")
                                    .font(.caption2)
                            }
                            .frame(width: 80)
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("Feed")
                            .font(.headline.weight(.semibold))

                        Spacer()

                        NavigationLink {
                            GroupsView()
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Groups")
                                    .font(.caption2)
                            }
                            .frame(width: 80)
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                feedPresentCreateGroup = true
                            } label: {
                                Label("Create Group", systemImage: "plus.circle")
                            }
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(false)
        .onAppear {
            recomputeFeedSummariesIfNeeded()
        }
        .onChange(of: firestore.posts.count) { _, _ in
            recomputeFeedSummariesIfNeeded()
        }
        .onChange(of: firestore.followingIds) { _, _ in
            recomputeFeedSummariesIfNeeded()
        }
        .onChange(of: firestore.errorMessage) { _, message in
            guard let message, !message.isEmpty else { return }
            if showFirestoreAlert, message == lastFirestoreAlertText {
                firestore.clearErrorMessage()
                return
            }
            firestoreAlertText = message
            lastFirestoreAlertText = message
            showFirestoreAlert = true
            firestore.clearErrorMessage()
        }
        .alert("Something went wrong", isPresented: $showFirestoreAlert) {
            Button("OK", role: .cancel) {
                showFirestoreAlert = false
                firestoreAlertText = ""
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

    private func recomputeFeedSummariesIfNeeded() {
        let posts = firestore.posts
        let signature = posts
            .map { "\($0.id)|\($0.authorId)|\($0.intensity ?? -1)|\($0.primaryEmotion)" }
            .joined(separator: ";")
            + "|f:\(firestore.followingIds.sorted().joined(separator: ","))"
        guard signature != feedSummarySignature else { return }
        feedSummarySignature = signature
        cachedSoftSocialNudgeLine = softSocialNudgeLine
        cachedWeeklyHelpfulTagsLine = weeklyHelpfulTagsLine
    }

    @ViewBuilder
    private var feedReactionPaletteOverlay: some View {
        if let p = palettePost {
            ZStack {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("reaction_overlay_background")
                    .onTapGesture {
                        dismissExpandedReactionPalette()
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
                                    dismissExpandedReactionPalette()
                                } catch {
                                    AppLogger.error("Reaction apply failed: \(error.localizedDescription)")
                                }
                            }
                        }
                    )
                    .allowsHitTesting(true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height > 24 {
                            dismissExpandedReactionPalette()
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissExpandedReactionPalette()
                }
            )
        }
    }

    private func dismissExpandedReactionPalette() {
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedReactionPostId = nil
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

    @State private var showInviteSheet = false

    private var uid: String? { auth.currentUser?.id }
    private var livePost: FeedPost {
        post
    }
    private var isFollowingAuthor: Bool {
        firestore.isFollowing(livePost.authorId)
    }

    var body: some View {
        cardBody
            .accessibilityElement(children: .contain)
            .onLongPressGesture(minimumDuration: 0.45, pressing: nil) {
                guard uid != nil else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                expandedReactionPostId = post.id
            }
            .accessibilityIdentifier("feed_post_\(post.id)")
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                NavigationLink {
                    ProfileView(userId: livePost.authorId, contextPost: livePost)
                        .environmentObject(firestore)
                        .environmentObject(auth)
                } label: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.orange.opacity(0.85))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("feed_author_avatar_\(livePost.authorId)")

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
                        .accessibilityIdentifier("feed_author_name_\(livePost.authorId)")
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

                            Button {
                                showInviteSheet = true
                            } label: {
                                Text("Invite")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color.orange.opacity(0.14))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.borderless)
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
                        Text((livePost.createdAt ?? .now).formatted(.dateTime.month().day().year()))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.secondary.opacity(0.95))
                }
            }

            if let title = livePost.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let urlString = livePost.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.12))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            )
                    @unknown default:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipped()
                .cornerRadius(12)
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
                        .foregroundStyle(FeedEmotionPalette.chipForeground(for: label))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(FeedEmotionPalette.chipBackground(for: label))
                        .clipShape(Capsule())
                }
                if let intensity = livePost.intensity {
                    Text("Intensity \(intensity)/10")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
            }

            if !livePost.insight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(livePost.insight)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

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

            if !livePost.helpfulTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(livePost.helpfulTags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            let isAuthor = uid == livePost.authorId
            let canShowReactions = !livePost.hideReactions || isAuthor
            if canShowReactions {
                FeedReactionRow(
                    livePost: livePost,
                    uid: uid,
                    showCounts: true,
                    onOpenPalette: { expandedReactionPostId = post.id }
                )
            }

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

                if livePost.commentsEnabled || isAuthor {
                    Label("\(livePost.commentCount)", systemImage: "bubble.right.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

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
        .sheet(isPresented: $showInviteSheet) {
            ActivityInviteSheet(
                recipientName: livePost.user.name,
                recipientUserId: livePost.authorId
            )
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
        .environmentObject(ResourceRecommendationManager.shared)
        .environmentObject(ProfileManager.shared)
        .onAppear {
            firestore.applyPreviewPosts(SeedDataManager.previewSeedPosts())
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
            firestore.applyPreviewPosts(SeedDataManager.previewSeedPosts())
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
        .environmentObject(ResourceRecommendationManager.shared)
        .environmentObject(ProfileManager.shared)
        .onAppear {
            firestore.applyPreviewPosts(SeedDataManager.previewSeedPosts())
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
