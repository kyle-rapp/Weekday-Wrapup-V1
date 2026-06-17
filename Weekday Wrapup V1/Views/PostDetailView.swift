import SwiftUI

/// FILE: Views/PostDetailView.swift
/// Full post + reactions + likes + live comments (`posts/{id}/comments`).

private let detailBackground = Color(red: 0.99, green: 0.97, blue: 0.94)

struct PostDetailView: View {
    let post: FeedPost
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @EnvironmentObject private var resourceRecs: ResourceRecommendationManager
    @State private var newComment = ""
    @State private var isPostingComment = false
    @State private var showErrorAlert = false
    @State private var alertMessage = ""
    @State private var showExpandedReactionPalette = false
    /// Author onboarding stressors (optional) for resource scoring.
    @State private var authorStressors: [String] = []
    @State private var showInviteSheet = false
    @State private var showReportSheet = false
    @State private var showBlockConfirm = false
    @State private var showDeleteConfirm = false

    private var uid: String? { auth.currentUser?.id }
    private var livePost: FeedPost {
        firestore.posts.first(where: { $0.id == post.id }) ?? post
    }
    private var isAuthor: Bool {
        uid == livePost.authorId
    }
    private var likesAllowed: Bool {
        livePost.commentsEnabled || !livePost.hideReactions
    }

    private var isFollowingAuthor: Bool {
        firestore.isFollowing(livePost.authorId)
    }

    private var postBlobForMatching: String {
        [livePost.insight, livePost.whoop, livePost.goal, livePost.whatHelped ?? ""]
            .joined(separator: " ")
    }

    private var rankedResources: [ResourceRecommendation] {
        resourceRecs.recommendations(
            postId: livePost.id,
            postText: postBlobForMatching,
            emotionTags: livePost.selectedEmotions,
            stressors: authorStressors
        )
    }

    var body: some View {
        ZStack {
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

                    PostMediaAttachmentView(post: livePost, height: 260)

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

                    if !rankedResources.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Helpful resources for you")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(rankedResources) { rec in
                                if let url = URL(string: rec.url),
                                   let scheme = url.scheme?.lowercased(),
                                   scheme == "http" || scheme == "https" {
                                    Link(destination: url) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(rec.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.leading)
                                            Text(rec.summary)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                            HStack(spacing: 6) {
                                                Text("Open link")
                                                    .font(.caption.weight(.semibold))
                                                Image(systemName: "arrow.up.right.square")
                                                    .font(.caption.weight(.semibold))
                                            }
                                            .foregroundStyle(.blue)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.blue.opacity(0.07))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.blue.opacity(0.12), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }

                    if !livePost.hideReactions {
                        FeedReactionRow(
                            livePost: livePost,
                            uid: uid,
                            onOpenPalette: {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                    showExpandedReactionPalette = true
                                }
                            }
                        )
                    } else {
                        Label("Reactions hidden by author", systemImage: "eye.slash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if likesAllowed || livePost.commentsEnabled {
                        HStack(spacing: 20) {
                            if likesAllowed {
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
                            }

                            if livePost.commentsEnabled {
                                Label("\(livePost.commentCount) Comment\(livePost.commentCount == 1 ? "" : "s")", systemImage: "bubble.right.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }

                    if livePost.commentsEnabled {
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
                                    FeedCommentRow(postId: livePost.id, comment: comment, depth: 0)
                                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
                                }
                            }
                            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: firestore.detailComments.count)
                        }

                        commentComposer
                    } else {
                        Label("Comments are turned off for this post.", systemImage: "bubble.right.slash.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                    }
                }
                .padding(22)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in
                        guard !livePost.hideReactions else { return }
                        guard uid != nil else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            showExpandedReactionPalette = true
                        }
                    }
            )

            if showExpandedReactionPalette {
                postDetailReactionOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: showExpandedReactionPalette)
        .background(detailBackground.ignoresSafeArea())
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                postActionsMenu
            }
        }
        .onAppear {
            feedViewModel.clearReplyTarget()
            firestore.startCommentsListener(postId: post.id)
        }
        .task(id: livePost.authorId) {
            let stressors: [String]
            if livePost.authorId == auth.currentUser?.id,
               let prefs = await firestore.fetchUserPreferences(userId: livePost.authorId) {
                stressors = prefs.topStressors
            } else {
                // Others’ preferences are private per Firestore rules — score from post text + emotions only.
                stressors = []
            }
            await MainActor.run {
                resourceRecs.invalidate(postId: livePost.id)
                authorStressors = stressors
            }
        }
        .onDisappear {
            resourceRecs.invalidate(postId: post.id)
            firestore.stopCommentsListener()
            feedViewModel.clearReplyTarget()
        }
        .alert("Something went wrong", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                showErrorAlert = false
            }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showInviteSheet) {
            ActivityInviteSheet(
                recipientName: livePost.user.name,
                recipientUserId: livePost.authorId
            )
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView(
                title: "Report post",
                target: ReportTarget(reportedUserId: livePost.authorId, reportedPostId: livePost.id)
            ) {
                presentAlert("Thanks for letting us know. We'll review this.")
            }
            .environmentObject(auth)
            .environmentObject(firestore)
        }
        .confirmationDialog("Block this user?", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("Block user", role: .destructive) {
                Task { await blockAuthor() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won’t see posts from this person anymore.")
        }
        .confirmationDialog("Delete this post?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete post", role: .destructive) {
                Task { await deletePost() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func presentAlert(_ message: String) {
        alertMessage = message
        showErrorAlert = true
    }

    private var postActionsMenu: some View {
        Menu {
            if isAuthor {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete post", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    showReportSheet = true
                } label: {
                    Label("Report post", systemImage: "exclamationmark.bubble")
                }
                Button(role: .destructive) {
                    showBlockConfirm = true
                } label: {
                    Label("Block user", systemImage: "person.crop.circle.badge.xmark")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func blockAuthor() async {
        guard let uid, uid != livePost.authorId else { return }
        do {
            try await firestore.blockUser(currentUserId: uid, blockedUserId: livePost.authorId)
            presentAlert("You won’t see posts from this person anymore.")
        } catch {
            presentAlert("We couldn't block this user right now.")
        }
    }

    private func deletePost() async {
        guard let uid, uid == livePost.authorId else { return }
        do {
            try await firestore.deleteOwnPost(postId: livePost.id, currentUserId: uid)
            presentAlert("Post deleted.")
        } catch {
            presentAlert("We couldn't delete this post right now.")
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 56, height: 56)
                .foregroundStyle(.orange.opacity(0.88))
            VStack(alignment: .leading, spacing: 6) {
                NavigationLink {
                    ProfileView(userId: livePost.authorId, contextPost: livePost)
                        .environmentObject(firestore)
                        .environmentObject(auth)
                } label: {
                    Text(livePost.user.name)
                        .font(.title2.bold())
                }
                .buttonStyle(.plain)
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
                VStack(alignment: .trailing, spacing: 8) {
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

                Button {
                    showInviteSheet = true
                } label: {
                    Text("Invite")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.16))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
                }
            }
        }
    }

    private var commentComposer: some View {
        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let canPost = !trimmed.isEmpty && uid != nil && !isPostingComment

        return VStack(alignment: .leading, spacing: 8) {
            if feedViewModel.replyTarget != nil {
                HStack {
                    Text("Replying to \(feedViewModel.replyTarget?.userName ?? "comment")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") {
                        feedViewModel.clearReplyTarget()
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 4)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    feedViewModel.replyTarget == nil ? "Add a comment…" : "Write a reply…",
                    text: $newComment,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                Button("Post") {
                    guard let uid, let name = auth.currentUser?.name else { return }
                    Task { @MainActor in
                        isPostingComment = true
                        defer { isPostingComment = false }
                        do {
                            if let parent = feedViewModel.replyTarget {
                                try await feedViewModel.addReply(
                                    postId: livePost.id,
                                    parentId: parent.id,
                                    text: newComment,
                                    userId: uid,
                                    userName: name
                                )
                                feedViewModel.clearReplyTarget()
                            } else {
                                try await firestore.addComment(postId: livePost.id, userId: uid, userName: name, text: newComment)
                            }
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
        }
        .padding(.top, 8)
    }

    private var postDetailReactionOverlay: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showExpandedReactionPalette = false
                    }
                }

            VStack {
                Spacer()
                ExpandedReactionPalette(
                    reactionCounts: livePost.reactions,
                    selectedEmoji: livePost.reactionForCurrentUser(uid),
                    onPick: { emoji in
                        guard let uid else { return }
                        Task { @MainActor in
                            do {
                                try await firestore.applyReaction(postId: livePost.id, userId: uid, emoji: emoji)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    showExpandedReactionPalette = false
                                }
                            } catch {
                                print("❌ Reaction failed: \(error.localizedDescription)")
                                presentAlert(error.localizedDescription)
                                firestore.clearErrorMessage()
                            }
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
                .scaleEffect(showExpandedReactionPalette ? 1 : 0.9)
                .opacity(showExpandedReactionPalette ? 1 : 0)
            }
        }
    }
}

// MARK: - Comment row (likes, reply, nested replies)

private struct FeedCommentRow: View {
    let postId: String
    let comment: Comment
    var depth: Int = 0
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @State private var showReportSheet = false
    @State private var showReportThanks = false

    private var currentUserId: String? { auth.currentUser?.id }

    private var isLikedByMe: Bool {
        guard let id = currentUserId else { return false }
        return comment.likedBy.contains(id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(comment.userName)
                    .font(.subheadline.weight(.semibold))
                if comment.parentCommentId != nil {
                    Text("Reply")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                }
                Spacer()
                Text(RelativeTimeFormat.string(for: comment.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Menu {
                    Button(role: .destructive) {
                        showReportSheet = true
                    } label: {
                        Label("Report comment", systemImage: "exclamationmark.bubble")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(comment.text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            HStack(spacing: 18) {
                Button {
                    guard let uid = currentUserId else { return }
                    Task {
                        await feedViewModel.toggleLikeComment(
                            postId: postId,
                            comment: comment,
                            currentUserId: uid
                        )
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isLikedByMe ? "heart.fill" : "heart")
                        Text("\(comment.likes)")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isLikedByMe ? .pink : .secondary)
                }
                .buttonStyle(.borderless)
                .disabled(currentUserId == nil)

                Button("Reply") {
                    feedViewModel.setReplyTarget(comment)
                }
                .font(.caption.weight(.semibold))
            }

            HStack(spacing: 10) {
                commentReactionChip(emoji: "❤️", postId: postId, comment: comment)
                commentReactionChip(emoji: "😌", postId: postId, comment: comment)
                commentReactionChip(emoji: "🥺", postId: postId, comment: comment)
            }

            ForEach(comment.replies) { reply in
                FeedCommentRow(postId: postId, comment: reply, depth: depth + 1)
                    .padding(.leading, CGFloat(min(depth + 1, 6) * 14))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.orange.opacity(0.08)))
        .padding(.leading, depth == 0 ? 0 : CGFloat(min(depth, 6) * 4))
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView(
                title: "Report comment",
                target: ReportTarget(
                    reportedUserId: comment.userId,
                    reportedPostId: postId,
                    reportedCommentId: comment.id
                )
            ) {
                showReportThanks = true
            }
            .environmentObject(auth)
            .environmentObject(firestore)
        }
        .alert("Thanks for letting us know. We'll review this.", isPresented: $showReportThanks) {
            Button("OK", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func commentReactionChip(emoji: String, postId: String, comment: Comment) -> some View {
        let count = comment.reactions[emoji] ?? 0
        Button {
            guard let uid = currentUserId else { return }
            Task {
                await feedViewModel.incrementCommentReaction(
                    postId: postId,
                    comment: comment,
                    emoji: emoji,
                    currentUserId: uid
                )
            }
        } label: {
            HStack(spacing: 3) {
                Text(emoji)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.borderless)
        .disabled(currentUserId == nil)
    }
}
