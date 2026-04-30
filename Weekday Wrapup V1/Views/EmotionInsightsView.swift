import SwiftUI

/// FILE: Views/EmotionInsightsView.swift
/// Patterns from posted wrapups (Firestore), not the local emotion-router history.

struct EmotionInsightsView: View {
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    private var entries: [CheckInData] {
        firestore.wrapupHistoryEntries(forUserId: auth.currentUser?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Emotional Patterns")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.colors.textPrimary)

            if entries.isEmpty {
                Text("Start logging emotions to see patterns.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
            } else {
                Text("Most frequent emotion:")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textPrimary)

                Text(topEmotion())
                    .font(.headline)
                    .foregroundStyle(Color.blue)

                Text("Total check-ins: \(entries.count)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.colors.textSecondary)

                Text(intensityTrend())
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func intensityTrend() -> String {
        guard entries.count > 5 else { return "Log more to see patterns." }

        let last = entries.suffix(5).compactMap(\.intensity)
        guard let first = last.first, let final = last.last else { return "" }

        if final < first {
            return "Your emotional intensity has been decreasing recently."
        } else if final > first {
            return "Things have been more intense lately — take care of yourself."
        } else {
            return "Your emotional intensity has been steady."
        }
    }

    private func topEmotion() -> String {
        let all = entries.flatMap { $0.selectedEmotions }
        let counts = Dictionary(grouping: all, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key ?? "—"
    }
}
