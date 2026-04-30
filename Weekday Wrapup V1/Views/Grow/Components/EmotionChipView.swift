import SwiftUI

/// FILE: Views/Grow/Components/EmotionChipView.swift
/// Capsule filter chip for emotion filters on Grow.

struct EmotionChipView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.colors.pine : Color.gray.opacity(0.15))
                )
                .foregroundStyle(isSelected ? Color.white : AppTheme.colors.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
