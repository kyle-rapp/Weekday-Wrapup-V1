import SwiftUI

struct FindFriendsView: View {
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    @State private var query = ""
    @State private var results: [AppUser] = []
    @State private var suggested: [AppUser] = []
    @State private var loading = false

    var body: some View {
        List {
            if !suggested.isEmpty {
                Section("Suggested for you") {
                    ForEach(suggested) { user in
                        friendRow(user)
                    }
                }
            }

            Section("Search") {
                ForEach(results) { user in
                    friendRow(user)
                }
                if results.isEmpty, !query.isEmpty {
                    Text("No users found")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Find Friends")
        .searchable(text: $query, prompt: "Search by name")
        .overlay {
            if loading {
                ProgressView()
            }
        }
        .task {
            await loadRecommendations()
            await runSearch()
        }
        .onChange(of: query) { _, _ in
            Task { await runSearch() }
        }
    }

    @ViewBuilder
    private func friendRow(_ user: AppUser) -> some View {
        HStack(spacing: 12) {
            NavigationLink {
                UserProfileView(userId: user.id)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(user.followerCount) followers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 8)
            Button {
                Task { await toggleFollow(userId: user.id) }
            } label: {
                Text(firestore.isFollowing(user.id) ? "Following" : "Follow")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(firestore.isFollowing(user.id) ? Color.green.opacity(0.16) : Color.blue.opacity(0.12))
                    .foregroundStyle(firestore.isFollowing(user.id) ? .green : .blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func runSearch() async {
        loading = true
        let users = await firestore.searchUsers(query: query)
        let me = auth.currentUser?.id
        results = users.filter { $0.id != me }
        loading = false
    }

    private func loadRecommendations() async {
        guard let current = auth.currentUser else { return }
        suggested = await firestore.recommendUsers(for: current)
    }

    private func toggleFollow(userId: String) async {
        guard let currentUserId = auth.currentUser?.id, currentUserId != userId else { return }
        do {
            if firestore.isFollowing(userId) {
                try await firestore.unfollowUser(currentUserId: currentUserId, targetUserId: userId)
            } else {
                try await firestore.followUser(currentUserId: currentUserId, targetUserId: userId)
            }
            await runSearch()
            await loadRecommendations()
        } catch {
            AppLogger.error("FindFriends toggle follow failed: \(error.localizedDescription)")
        }
    }
}
