import SwiftUI

/// FILE: Views/Grow/Components/RecommendationCardView.swift
/// Calm card for a single personalized recommendation + optional feedback.

struct RecommendationCardView: View {
    let recommendation: Recommendation
    /// `true` = thumbs up, `false` = thumbs down, `nil` = none selected.
    var selectedFeedback: Bool?
    var onStart: () -> Void
    var onFeedback: ((Bool) -> Void)?
    @State private var feedbackState: Bool?

    var body: some View {
        let isUp = feedbackState == true
        let isDown = feedbackState == false

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

            if onFeedback != nil {
                HStack(spacing: 20) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let next: Bool? = (feedbackState == true) ? nil : true
                        withAnimation(.easeInOut(duration: 0.2)) {
                            feedbackState = next
                        }
                        if next != selectedFeedback {
                            onFeedback?(true)
                        }
                    } label: {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.title3)
                            .foregroundStyle(isUp ? Color.green : Color.gray)
                            .scaleEffect(isUp ? 1.2 : 1.0)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Helpful")

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let next: Bool? = (feedbackState == false) ? nil : false
                        withAnimation(.easeInOut(duration: 0.2)) {
                            feedbackState = next
                        }
                        if next != selectedFeedback {
                            onFeedback?(false)
                        }
                    } label: {
                        Image(systemName: "hand.thumbsdown.fill")
                            .font(.title3)
                            .foregroundStyle(isDown ? Color.red : Color.gray)
                            .scaleEffect(isDown ? 1.2 : 1.0)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Not helpful")
                }
                .padding(.top, 4)
                .animation(.easeInOut(duration: 0.2), value: feedbackState)
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
        .onAppear {
            feedbackState = selectedFeedback
        }
        .onChange(of: selectedFeedback) { _, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                feedbackState = newValue
            }
        }
    }

    private func iconName(for type: RecommendationType) -> String {
        switch type {
        case .regulation: return "wind"
        case .reflection: return "book.pages"
        case .action: return "figure.walk"
        case .connection: return "bubble.left.and.bubble.right"
        }
    }
}
