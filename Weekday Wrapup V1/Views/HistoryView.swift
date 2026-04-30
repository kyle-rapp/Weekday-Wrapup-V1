import SwiftUI

/// FILE: Views/HistoryView.swift
/// Past wrapups for the signed-in user (from feed-backed posts).

struct HistoryView: View {
    let entries: [CheckInData]

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No past wrapups yet",
                    systemImage: "calendar",
                    description: Text("When you post from Share, your weeks show up here.")
                )
            } else {
                List(entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Week \(entry.weekNumber)")
                            .font(.headline)
                            .foregroundStyle(AppTheme.colors.textPrimary)
                        Text(entry.selectedEmotions.sorted().joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.colors.textSecondary)
                        if !entry.emotionalInsight.isEmpty {
                            Text(entry.emotionalInsight)
                                .font(.caption)
                                .foregroundStyle(AppTheme.colors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Past weeks")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.colors.secondaryBackground.ignoresSafeArea())
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        HistoryView(entries: [
            CheckInData(
                userName: "Alex",
                astrologySign: "♈︎",
                weekNumber: 12,
                weeklyEmoji: "🌿",
                checkInImage: nil,
                selectedEmotions: Set(["Peaceful", "Hopeful"]),
                emotionalInsight: "Steady week.",
                whoopsText: "",
                poopsText: "",
                weeklyGoal: "Walk daily",
                monthlyGoal: "",
                selectedEmotionsOrdered: ["Peaceful", "Hopeful"]
            )
        ])
    }
}
#endif
