import SwiftUI

struct UserProfileView: View {
    let userId: String

    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    @State private var user: AppUser?
    @State private var isFollowing: Bool = false
    @State private var followers: [AppUser] = []
    @State private var following: [AppUser] = []
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var loading = false
    @State private var showThinkingOfYouToast = false
    @State private var thinkingOfYouInFlight = false
    @State private var showReportSheet = false
    @State private var showBlockConfirm = false
    @State private var showSafetyAlert = false
    @State private var safetyAlertText = ""

    private var isSelf: Bool { auth.currentUser?.id == userId }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(user?.name ?? "Profile")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                statsRow

                if !isSelf {
                    VStack(spacing: 10) {
                        Button {
                            Task { await toggleFollow() }
                        } label: {
                            Text(isFollowing ? "Following" : "Follow")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isFollowing ? Color.gray.opacity(0.15) : Color.blue.opacity(0.15))
                                .foregroundStyle(isFollowing ? Color.primary : Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await sendThinkingOfYou() }
                        } label: {
                            Label("Thinking of you 💛", systemImage: "heart")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.pink.opacity(0.10))
                                .foregroundStyle(Color.pink.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(thinkingOfYouInFlight)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isSelf {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showReportSheet = true
                        } label: {
                            Label("Report user", systemImage: "exclamationmark.bubble")
                        }
                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label("Block user", systemImage: "person.crop.circle.badge.xmark")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .overlay {
            if loading {
                ProgressView()
            }
        }
        .overlay(alignment: .bottom) {
            if showThinkingOfYouToast {
                Text("They'll know you're thinking of them 💛")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.pink.opacity(0.85))
                            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    )
                    .padding(.bottom, 36)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showThinkingOfYouToast)
        .task { await loadProfile() }
        .sheet(isPresented: $showFollowers) {
            NavigationStack {
                SocialListView(title: "Followers", users: followers)
            }
        }
        .sheet(isPresented: $showFollowing) {
            NavigationStack {
                SocialListView(title: "Following", users: following)
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView(
                title: "Report user",
                target: ReportTarget(reportedUserId: userId)
            ) {
                safetyAlertText = "Thanks for letting us know. We'll review this."
                showSafetyAlert = true
            }
            .environmentObject(auth)
            .environmentObject(firestore)
        }
        .confirmationDialog("Block this user?", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("Block user", role: .destructive) {
                Task { await blockUser() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won’t see posts from this person anymore.")
        }
        .alert(safetyAlertText, isPresented: $showSafetyAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(title: "Posts", value: user?.postCount ?? 0, action: nil)
            statTile(title: "Followers", value: user?.followerCount ?? 0) {
                Task {
                    followers = await firestore.fetchFollowers(userId: userId)
                    showFollowers = true
                }
            }
            statTile(title: "Following", value: user?.followingCount ?? 0) {
                Task {
                    following = await firestore.fetchFollowingUsers(userId: userId)
                    showFollowing = true
                }
            }
        }
    }

    private func statTile(title: String, value: Int, action: (() -> Void)?) -> some View {
        Group {
            if let action {
                Button(action: action) {
                    tileContents(title: title, value: value)
                }
                .buttonStyle(.plain)
            } else {
                tileContents(title: title, value: value)
            }
        }
    }

    private func tileContents(title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
    }

    private func loadProfile() async {
        loading = true
        async let userTask = firestore.fetchAppUserProfile(userId: userId)
        async let followerCountTask = firestore.fetchFollowerCount(userId: userId)
        async let followingCountTask = firestore.fetchFollowingCount(userId: userId)
        let loadedUser = await userTask
        let followerCount = await followerCountTask
        let followingCount = await followingCountTask
        var value = loadedUser
        value?.followerCount = followerCount
        value?.followingCount = followingCount
        user = value
        isFollowing = firestore.isFollowing(userId)
        loading = false
    }

    private func toggleFollow() async {
        guard let currentUserId = auth.currentUser?.id, currentUserId != userId else { return }
        do {
            if isFollowing {
                try await firestore.unfollowUser(currentUserId: currentUserId, targetUserId: userId)
                isFollowing = false
            } else {
                try await firestore.followUser(currentUserId: currentUserId, targetUserId: userId)
                isFollowing = true
            }
            await loadProfile()
        } catch {
            AppLogger.error("UserProfileView follow toggle failed: \(error.localizedDescription)")
        }
    }

    private func sendThinkingOfYou() async {
        guard let from = auth.currentUser?.id, from != userId else { return }
        thinkingOfYouInFlight = true
        defer { Task { @MainActor in thinkingOfYouInFlight = false } }
        do {
            try await firestore.sendThinkingOfYou(from: from, to: userId)
            await MainActor.run {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { showThinkingOfYouToast = true }
            }
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            await MainActor.run {
                withAnimation { showThinkingOfYouToast = false }
            }
        } catch {
            AppLogger.error("UserProfileView sendThinkingOfYou failed: \(error.localizedDescription)")
        }
    }

    private func blockUser() async {
        guard let currentUserId = auth.currentUser?.id, currentUserId != userId else { return }
        do {
            try await firestore.blockUser(currentUserId: currentUserId, blockedUserId: userId)
            safetyAlertText = "You won’t see posts from this person anymore."
            showSafetyAlert = true
        } catch {
            safetyAlertText = "We couldn't block this user right now."
            showSafetyAlert = true
        }
    }
}

private struct SocialListView: View {
    let title: String
    let users: [AppUser]

    var body: some View {
        List(users) { user in
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.body.weight(.semibold))
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
