import SwiftUI

/// FILE: Views/Components/WhatHelpedInputView.swift
/// “What helped?” free text + flow chips (saved as `whatHelped` / `helpfulText` + `helpfulTags` on post).

struct TagChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.colors.pine.opacity(0.42) : Color.gray.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? AppTheme.colors.pine : Color.gray.opacity(0.28), lineWidth: 1.2)
                )
                .foregroundStyle(isSelected ? AppTheme.colors.textPrimary : AppTheme.colors.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) tag, \(isSelected ? "selected" : "not selected")")
    }
}

struct WhatHelpedInputView: View {
    @Binding var selectedTags: Set<String>
    @Binding var detailText: String
    var suggestedTags: [String] = HelpfulTags.presets

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What helped?")
                .font(.headline)
                .foregroundStyle(AppTheme.colors.textPrimary)

            TextField("Music, talking to a friend, gym...", text: $detailText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)

            FlowLayout(spacing: 8) {
                ForEach(suggestedTags, id: \.self) { tag in
                    TagChip(
                        title: tag,
                        isSelected: selectedTags.contains(tag),
                        onTap: { toggleTag(tag) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
}
