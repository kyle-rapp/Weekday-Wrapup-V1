import SwiftUI

/// FILE: Views/Components/ContextualResourceCardView.swift
/// Quote + external resource card for after-share recommendations.

struct ContextualResourceCardView: View {
    let resource: ContextualCheckInResource

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("“\(resource.quote)”")
                .font(.subheadline)
                .italic()
                .foregroundStyle(AppTheme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(resource.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let url = URL(string: resource.url) {
                Link(destination: url) {
                    Label("Open resource", systemImage: "arrow.up.right.square")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.colors.ocean)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.colors.sage.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.colors.sage.opacity(0.16), lineWidth: 1)
        )
    }
}
