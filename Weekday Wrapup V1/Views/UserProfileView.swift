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

    private var isSelf: Bool { auth.currentUser?.id == userId }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(user?.name ?? "Profile")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                statsRow

                if !isSelf {
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
                }
            }
            .padding(20)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if loading {
                ProgressView()
            }
        }
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
