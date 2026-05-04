import SwiftUI

/// FILE: Views/EmotionCalendarView.swift
/// Scrollable month heatmap from wrapup intensities.

struct EmotionCalendarView: View {
    let entries: [CheckInData]
    @StateObject private var viewModel = CalendarViewModel()

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let calendar = Calendar.current
    private let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

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
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(viewModel.months.enumerated()), id: \.offset) { index, month in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(monthTitle(from: month))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.colors.textPrimary)

                                LazyVGrid(columns: columns, spacing: 6) {
                                    ForEach(weekdaySymbols, id: \.self) { symbol in
                                        Text(symbol)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.bottom, 2)

                                LazyVGrid(columns: columns, spacing: 6) {
                                    ForEach(month) { day in
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(color(for: day.entry?.intensity))
                                            .frame(height: 28)
                                    }
                                }
                            }
                            .onAppear {
                                if index == viewModel.months.count - 1 {
                                    viewModel.loadOlderMonths(entries: entries)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if viewModel.months.isEmpty {
                viewModel.generateMonths(entries: entries)
            }
        }
        .onChange(of: entries.map(\.id)) { _ in
            viewModel.generateMonths(entries: entries)
        }
    }

    func monthTitle(from days: [CalendarDay]) -> String {
        guard let monthAnchor = days.first(where: { calendar.component(.day, from: $0.date) == 1 })?.date ?? days.first?.date else {
            return ""
        }
        return monthAnchor.formatted(.dateTime.month(.wide).year())
    }

    private func color(for intensity: Int?) -> Color {
        guard let i = intensity else { return .gray.opacity(0.14) }

        switch i {
        case 1...3: return .green.opacity(0.45)
        case 4...6: return .yellow.opacity(0.6)
        default: return .red.opacity(0.8)
        }
    }
}
