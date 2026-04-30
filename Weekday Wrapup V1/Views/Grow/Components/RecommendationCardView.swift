import SwiftUI

/// FILE: Views/Grow/Components/RecommendationCardView.swift
/// Calm card for a single personalized recommendation + optional feedback.

struct RecommendationCardView: View {
    let recommendation: Recommendation
    var onStart: () -> Void
    var onFeedback: ((Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: iconName(for: recommendation.type))
                    .font(.title3)
                    .foregroundStyle(AppTheme.colors.ocean)
                Text(recommendation.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(recommendation.reason)
                .font(.subheadline)
                .foregroundStyle(AppTheme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onStart) {
                Text(recommendation.action)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.colors.pine)

            if let feedback = onFeedback {
                HStack(spacing: 16) {
                    feedbackButton(label: "Helpful", emoji: "👍", positive: true, action: { feedback(true) })
                    feedbackButton(label: "Not helpful", emoji: "👎", positive: false, action: { feedback(false) })
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.colors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: AppTheme.colors.bark.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private func iconName(for type: RecommendationType) -> String {
        switch type {
        case .regulation: return "wind"
        case .reflection: return "book.pages"
        case .action: return "figure.walk"
        case .connection: return "bubble.left.and.bubble.right"
        }
    }

    @ViewBuilder
    private func feedbackButton(label: String, emoji: String, positive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(emoji)
                .font(.title3)
                .padding(10)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
