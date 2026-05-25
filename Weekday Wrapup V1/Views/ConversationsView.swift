import SwiftUI

/// FILE: Views/ConversationsView.swift
/// Lists all 1:1 conversations for the current user.

struct ConversationsView: View {
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    @State private var conversations: [Conversation] = []
    @State private var loading = true
    @State private var nameCache: [String: String] = [:]

    private var myId: String? { auth.currentUser?.id }

    var body: some View {
        Group {
            if loading {
                ProgressView("Loading messages…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if conversations.isEmpty {
                VStack(spacing: 20) {
                    Text("💛")
                        .font(.system(size: 48))
                    Text("Start a conversation with a friend")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    Text("Check in on someone you care about")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    NavigationLink {
                        FindFriendsView()
                            .environmentObject(firestore)
                            .environmentObject(auth)
                    } label: {
                        Text("Message a friend")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
            } else {
                List(conversations) { conv in
                    NavigationLink {
                        ChatView(
                            conversation: conv,
                            otherUserName: displayName(for: conv)
                        )
                        .environmentObject(firestore)
                        .environmentObject(auth)
                    } label: {
                        conversationRow(conv)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func conversationRow(_ conv: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayName(for: conv))
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
            if let last = conv.lastMessage, !last.isEmpty {
                Text(last)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let date = conv.updatedAt {
                Text(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func displayName(for conv: Conversation) -> String {
        guard let me = myId, let otherId = conv.otherUserId(myId: me) else { return "Unknown" }
        return nameCache[otherId] ?? String(otherId.prefix(10))
    }

    private func load() async {
        guard let me = myId else { loading = false; return }
        conversations = await firestore.fetchConversations(for: me)
        for conv in conversations {
            if let otherId = conv.otherUserId(myId: me), nameCache[otherId] == nil {
                let name = await firestore.userDisplayName(userId: otherId)
                await MainActor.run { nameCache[otherId] = name }
            }
        }
        await MainActor.run { loading = false }
    }
}
