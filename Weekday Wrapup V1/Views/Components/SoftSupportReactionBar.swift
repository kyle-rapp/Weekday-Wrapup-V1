import SwiftUI

/// FILE: Views/Components/SoftSupportReactionBar.swift
/// Compact reaction counts + toggle for soft social reactions.

struct SoftSupportReactionBar: View {
    let post: FeedPost
    let uid: String?

    @EnvironmentObject private var firestore: FirestoreManager

    var body: some View {
        HStack(spacing: 10) {
            ForEach(SoftSupportReactionKind.allCases, id: \.self) { kind in
                reactionButton(kind)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func reactionButton(_ kind: SoftSupportReactionKind) -> some View {
        let count = post.softSupportCount(kind)
        let selected = post.softSupportSelected(kind, userId: uid)
        return Button {
            guard let uid else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { @MainActor in
                do {
                    try await firestore.toggleSoftSupportReaction(postId: post.id, userId: uid, kind: kind)
                } catch {
                    print("❌ Soft reaction failed: \(error.localizedDescription)")
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text(kind.emoji)
                    .font(.system(size: 20))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.pink.opacity(0.14) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Color.pink.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(uid == nil)
        .accessibilityLabel("\(kind.shortLabel), \(count) reactions")
    }
}
