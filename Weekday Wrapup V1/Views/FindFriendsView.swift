import SwiftUI
import UIKit

private struct FindFriendsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct FindFriendsView: View {
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    @State private var query = ""
    @State private var results: [AppUser] = []
    @State private var suggested: [AppUser] = []
    @State private var loading = false
    @State private var showNativeInviteSheet = false
    @State private var directConversation: Conversation?
    @State private var directMessageUserName = "Message"
    @State private var showDirectMessage = false
    @State private var activeAlert: FindFriendsAlert?

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
        .navigationDestination(isPresented: $showDirectMessage) {
            if let directConversation {
                ChatView(conversation: directConversation, otherUserName: directMessageUserName)
                    .environmentObject(firestore)
                    .environmentObject(auth)
            } else {
                Text("Messaging is coming soon.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .alert(item: $activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
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
                Task { await openDirectMessage(with: user) }
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
            .accessibilityLabel("Message friend")
        }
    }

    private func runSearch() async {
        loading = true
        let users = await firestore.searchUsers(query: query)
        let me = auth.currentUser?.id
        results = users.filter { $0.id != me && !firestore.blockedUserIds.contains($0.id) }
        loading = false
    }

    private func loadRecommendations() async {
        guard let current = auth.currentUser else { return }
        suggested = await firestore.recommendUsers(for: current)
            .filter { !firestore.blockedUserIds.contains($0.id) }
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
            await MainActor.run {
                activeAlert = FindFriendsAlert(
                    title: "Couldn't update follow",
                    message: "Please try again in a moment."
                )
            }
        }
    }

    private func openDirectMessage(with user: AppUser) async {
        guard let myId = auth.currentUser?.id else { return }
        do {
            let conversation = try await firestore.fetchOrCreateConversation(between: myId, and: user.id)
            await MainActor.run {
                directConversation = conversation
                directMessageUserName = user.name
                showDirectMessage = true
            }
        } catch {
            AppLogger.error("FindFriends open DM failed: \(error.localizedDescription)")
            await MainActor.run {
                guard !showDirectMessage else { return }
                if (error as NSError).code == 403 {
                    activeAlert = FindFriendsAlert(
                        title: "Messaging",
                        message: "Messaging isn't available with this person right now."
                    )
                } else {
                    activeAlert = FindFriendsAlert(
                        title: "Messaging",
                        message: "Couldn't open messaging right now. Please try again."
                    )
                }
            }
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
