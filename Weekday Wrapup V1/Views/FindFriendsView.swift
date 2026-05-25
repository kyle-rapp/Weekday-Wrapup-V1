import SwiftUI
import UIKit

struct FindFriendsView: View {
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    @State private var query = ""
    @State private var results: [AppUser] = []
    @State private var suggested: [AppUser] = []
    @State private var loading = false
    @State private var showInviteSheet = false
    @State private var selectedUserForInvite: AppUser?
    @State private var showNativeInviteSheet = false

    var body: some View {
        List {
            Section {
                Button {
                    showNativeInviteSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.badge.plus")
                            .font(.body.weight(.semibold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Invite Friends")
                                .font(.subheadline.weight(.semibold))
                            Text("Share a warm invite to join you here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            if suggested.isEmpty && results.isEmpty && !loading {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.wave.2.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("No people yet")
                        .font(.headline)

                    Text("Invite friends or check back soon.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .listRowBackground(Color.clear)
            }

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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    ConversationsView()
                        .environmentObject(firestore)
                        .environmentObject(auth)
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }
                .accessibilityLabel("Messages")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNativeInviteSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Invite Friends")
            }
        }
        .sheet(isPresented: $showNativeInviteSheet) {
            AppInviteShareSheet()
        }
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
        .sheet(isPresented: $showInviteSheet) {
            if let user = selectedUserForInvite {
                NavigationStack {
                    SupportInviteSheetView { activity in
                        Task {
                            guard let fromUserId = auth.currentUser?.id, !fromUserId.isEmpty else { return }
                            do {
                                try await firestore.sendSupportInvite(
                                    fromUserId: fromUserId,
                                    targetUserId: user.id,
                                    activity: activity
                                )
                            } catch {
                                AppLogger.error("FindFriends invite failed: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
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

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selectedUserForInvite = user
                showInviteSheet = true
            } label: {
                Image(systemName: "paperplane")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.12))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Invite friend")
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

// MARK: - Native App Invite Share Sheet

struct AppInviteShareSheet: UIViewControllerRepresentable {
    private let message = "I've been using this app to reflect on emotions and mental health in a healthier way. Thought you might like it too 💛"
    // TODO: Replace with the real app deep link when available.
    private let inviteURL = URL(string: "https://weekdaywrapup.app/invite")!

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [message, inviteURL],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
