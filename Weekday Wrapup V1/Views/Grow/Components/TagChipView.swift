import SwiftUI

/// FILE: Views/Grow/Components/TagChipView.swift
/// Small capsule for helpful tags and future tagging UI.

struct TagChipView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(AppTheme.colors.mist.opacity(0.45)))
    }
}
