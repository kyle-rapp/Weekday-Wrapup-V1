import SwiftUI

/// FILE: Views/SupportInboxView.swift
/// Optional inbox for received support actions.

struct SupportInboxView: View {
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager
    @State private var items: [SupportInboxItem] = []

    var body: some View {
        List(items) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(itemTitle(item))
                    .font(.subheadline.weight(.semibold))
                Text(item.fromUserId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let d = item.createdAt {
                    Text(RelativeTimeFormat.string(for: d))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Support Inbox")
        .task { await refresh() }
    }

    private func refresh() async {
        guard let uid = auth.currentUser?.id else { return }
        items = await firestore.fetchSupportInbox(userId: uid)
    }

    private func itemTitle(_ item: SupportInboxItem) -> String {
        switch item.type {
        case .message:
            return item.text?.isEmpty == false ? "Message: \(item.text!)" : "Message"
        case .invite:
            return "Invite: \(item.activity ?? "Activity")"
        case .gift:
            return "Gift: \(item.itemTitle ?? "Wishlist item")"
        }
    }
}

