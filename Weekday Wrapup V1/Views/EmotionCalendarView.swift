import SwiftUI

/// FILE: Views/EmotionCalendarView.swift
/// 7-column heatmap from recent wrapup intensities.

struct EmotionCalendarView: View {
    let entries: [CheckInData]

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Emotional Patterns")
                .font(.headline)
                .foregroundStyle(AppTheme.colors.textPrimary)

            if entries.isEmpty {
                Text("Post wrapups to see your emotional history here.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
            } else {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(entries.prefix(35))) { entry in
                        Rectangle()
                            .fill(color(for: entry.intensity))
                            .frame(height: 28)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(for intensity: Int?) -> Color {
        guard let i = intensity else { return .gray.opacity(0.2) }

        switch i {
        case 1...3: return .green.opacity(0.4)
        case 4...6: return .yellow.opacity(0.6)
        default: return .red.opacity(0.8)
        }
    }
}
