import SwiftUI
import UIKit

/// FILE: Views/ExpandedReactionPalette.swift
/// Categorized full reaction picker — keys match `FeedReactions.all`.

struct ExpandedReactionPalette: View {
    let reactionCounts: [String: Int]
    let selectedEmoji: String?
    let onPick: (String) -> Void

    @State private var appeared = false

    private let gridColumns = [
        GridItem(.adaptive(minimum: 52), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick a reaction")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)

            ForEach(FeedReactions.paletteSections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(section.emojis, id: \.self) { emoji in
                            emojiCell(emoji)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.14), radius: 16, y: 6)
        )
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .allowsHitTesting(true)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private func emojiCell(_ emoji: String) -> some View {
        let count = reactionCounts[emoji] ?? 0
        let isSelected = selectedEmoji == emoji

        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onPick(emoji)
        } label: {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 30))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.65) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isSelected ? 1.06 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("React with \(emoji)\(count > 0 ? ", \(count) reactions" : "")")
        .accessibilityIdentifier("reaction_button_\(emoji)")
    }
}
