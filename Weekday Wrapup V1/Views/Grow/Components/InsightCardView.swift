import SwiftUI

/// FILE: Views/Grow/Components/InsightCardView.swift
/// Consistent insight / recommendation cards on Grow.

struct InsightCardView: View {
    let title: String
    let bodyText: String
    var icon: String? = nil
    var titleForeground: Color = AppTheme.colors.textPrimary
    var bodyForeground: Color = AppTheme.colors.textSecondary
    var backgroundFill: Color = AppTheme.colors.background
    var backgroundOpacity: Double = 1
    var strokeOpacity: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let icon {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(titleForeground)
            } else {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(titleForeground)
            }

            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(bodyForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(backgroundFill.opacity(backgroundOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(strokeOpacity), lineWidth: strokeOpacity > 0 ? 1 : 0)
        )
    }
}
