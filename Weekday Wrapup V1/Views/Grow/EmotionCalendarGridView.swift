import SwiftUI

/// FILE: Views/Grow/EmotionCalendarGridView.swift
/// Month grid for emotions; layout-only — logic lives in `CalendarViewModel`.

private enum GrowCalendarSelection {
    static let matchedID = "growCalendarDaySelection"
}

struct EmotionCalendarGridView: View {
    @ObservedObject var calendar: CalendarViewModel
    let entries: [CheckInData]
    var namespace: Namespace.ID

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var monthCells: [CalendarViewModel.MonthCell] {
        calendar.monthCells(for: calendar.displayedMonth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            monthPicker

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(calendar.weekdayHeaderSymbols.enumerated()), id: \.offset) { _, sym in
                    Text(sym)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthCells) { cell in
                    calendarDayCell(cell)
                }
            }
        }
    }

    private var monthPicker: some View {
        HStack {
            Button {
                calendar.shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.colors.ocean)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(calendar.monthTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.colors.textPrimary)

            Spacer()

            Button {
                calendar.shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.colors.ocean)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func calendarDayCell(_ cell: CalendarViewModel.MonthCell) -> some View {
        let dayEntry = cell.dateForDay.flatMap { calendar.lookupEntry(for: $0, entries: entries) }
        let dateForDayOpt = cell.dateForDay
        let isSelected = calendar.isSelectedDay(dateForDayOpt, selected: calendar.selectedCalendarDate)

        if let day = cell.dayNumber, let dateForDay = dateForDayOpt {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    calendar.selectDay(date: dateForDay, entry: dayEntry)
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(GrowCalendarPalette.colorForEntry(dayEntry))

                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.colors.pine.opacity(0.22))
                            .matchedGeometryEffect(id: GrowCalendarSelection.matchedID, in: namespace)
                            .shadow(color: AppTheme.colors.pine.opacity(0.4), radius: 8, x: 0, y: 2)
                    }

                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)

                    Text("\(day)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(GrowCalendarPalette.dayNumberColor(for: dayEntry))
                }
                .aspectRatio(1, contentMode: .fit)
                .scaleEffect(isSelected ? 1.15 : 1.0)
            }
            .buttonStyle(.plain)
            .opacity(dayEntry == nil ? 0.55 : 1)
            .accessibilityLabel(Text(accessibilityDayLabel(day: day, entry: dayEntry)))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
                .aspectRatio(1, contentMode: .fit)
        }
    }

    private func accessibilityDayLabel(day: Int, entry: CheckInData?) -> String {
        if let entry {
            return "Day \(day), intensity \(entry.intensity.map(String.init) ?? "none")"
        }
        return "Day \(day), no wrapup"
    }
}
