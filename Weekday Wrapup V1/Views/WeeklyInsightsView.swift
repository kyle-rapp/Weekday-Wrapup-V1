import SwiftUI

/// FILE: Views/WeeklyInsightsView.swift
/// Simple emotion-frequency summary from the user’s posted wrapups.

struct WeeklyInsightsView: View {
    let entries: [CheckInData]

    private var topEmotion: String {
        let all = entries.flatMap { $0.selectedEmotions.map { $0.lowercased() } }
        let counts = Dictionary(grouping: all, by: { $0 }).mapValues { $0.count }
        guard let best = counts.max(by: { $0.value < $1.value })?.key else { return "None" }
        return best.capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Weekly Insights")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.colors.textPrimary)

            if entries.isEmpty {
                Text("Post a wrapup from Share to see trends here.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
            } else {
                Text("Most frequent emotion: \(topEmotion)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textPrimary)
                Text("Total check-ins: \(entries.count)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    WeeklyInsightsView(entries: [
        CheckInData.fromPostedWrapup(
            FeedPost(
                id: "1",
                authorId: "u",
                user: FeedUser(id: "u", name: "Me"),
                emoji: "😊",
                insight: "Good week",
                whoop: "",
                goal: "Run",
                wrapupWeekNumber: 10,
                selectedEmotions: ["Peaceful", "tired", "Peaceful"]
            )
        )
    ])
    .padding()
    .background(AppTheme.colors.secondaryBackground)
}
#endif
