import SwiftUI
import UIKit

/// FILE: Views/Components/FeedReactionRow.swift
/// Exactly four emotion-based reactions + “more” — equal-width slots, no horizontal overflow.

private struct ReactionPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct FeedReactionRow: View {
    let livePost: FeedPost
    let uid: String?
    let onOpenPalette: () -> Void

    @EnvironmentObject private var firestore: FirestoreManager

    private var rowEmojis: [String] {
        ReactionManager.emotionBasedEmojis(for: livePost)
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(rowEmojis, id: \.self) { emoji in
                reactionSlot(emoji: emoji)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }

            Button {
                guard uid != nil else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onOpenPalette()
            } label: {
                Text("➕")
                    .font(.system(size: 16))
                    .frame(width: 36, height: 36)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(ReactionPressButtonStyle())
            .disabled(uid == nil)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("More reactions")
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func reactionSlot(emoji: String) -> some View {
        let count = livePost.reactions[emoji] ?? 0
        let selected = livePost.reactionForCurrentUser(uid) == emoji
        Button {
            guard let uid else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { @MainActor in
                do {
                    try await firestore.applyReaction(postId: livePost.id, userId: uid, emoji: emoji)
                } catch {
                    print("❌ Reaction failed: \(error.localizedDescription)")
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text(emoji)
                    .font(.system(size: 22))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.18) : Color.orange.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(ReactionPressButtonStyle())
        .disabled(uid == nil)
        .scaleEffect(selected ? 1.04 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.68), value: selected)
        .accessibilityLabel("React with \(emoji), \(count) on this post")
    }
}
