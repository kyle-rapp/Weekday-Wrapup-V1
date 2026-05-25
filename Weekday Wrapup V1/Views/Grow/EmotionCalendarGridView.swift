import SwiftUI

/// FILE: Views/Grow/EmotionCalendarGridView.swift
/// Month grid for emotions; layout-only — logic lives in `CalendarViewModel`.

struct EmotionCalendarGridView: View {
    @ObservedObject var calendar: CalendarViewModel
    let entries: [CheckInData]
    let selectedEmotion: String?
    var namespace: Namespace.ID

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var monthCells: [CalendarViewModel.MonthCell] {
        calendar.monthCells(for: calendar.displayedMonth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack {
                monthPicker
            }
            .zIndex(100)
            .allowsHitTesting(true)

            Text("Swipe or tap arrows to explore past months")
                .font(.caption2)
                .foregroundStyle(AppTheme.colors.textSecondary)

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
            .zIndex(0)
        }
    }

    private var monthPicker: some View {
        HStack {
            Button {
                calendar.shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .background(
                        Circle()
                            .fill(AppTheme.colors.secondaryBackground)
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .zIndex(1000)
            .accessibilityIdentifier("calendar_prev_month")

            Spacer()

            Text(calendar.monthTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.colors.textPrimary)
                .accessibilityIdentifier("calendar_month_label")

            Spacer()

            Button {
                calendar.shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .background(
                        Circle()
                            .fill(AppTheme.colors.secondaryBackground)
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .zIndex(1000)
            .accessibilityIdentifier("calendar_next_month")
            .disabled(calendar.isCurrentMonth)
        }
        .contentShape(Rectangle())
        .zIndex(100)
    }

    @ViewBuilder
    private func calendarDayCell(_ cell: CalendarViewModel.MonthCell) -> some View {
        let rawDayEntry = cell.dateForDay.flatMap { calendar.lookupEntry(for: $0, entries: entries) }
        let dayEntry = filteredEntry(rawDayEntry, dateForDay: cell.dateForDay)
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
                            // Temporarily disabled to avoid any interaction-layer interference.
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

    private func filteredEntry(_ entry: CheckInData?, dateForDay: Date?) -> CheckInData? {
        guard let entry else { return nil }
        let normalizedSelected = selectedEmotion?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard !normalizedSelected.isEmpty else { return entry }

        let dayEmotions = Array(Set(
            entry.selectedEmotions.map { $0.lowercased() }
            + entry.selectedEmotionsOrdered.map { $0.lowercased() }
            + entry.selectedEmotionsArray.map { $0.lowercased() }
            + [entry.firstSelectedEmotionLabel.lowercased()]
        ))
        let passes = dayEmotions.contains(normalizedSelected)

        #if DEBUG
        let dayLabel = dateForDay?.formatted(date: .abbreviated, time: .omitted) ?? "unknown"
        print("[GROW_FILTER] selected='\(normalizedSelected)' day=\(dayLabel) emotions=\(dayEmotions.joined(separator: ",")) passes=\(passes)")
        #endif

        return passes ? entry : nil
    }

    private func accessibilityDayLabel(day: Int, entry: CheckInData?) -> String {
        if let entry {
            return "Day \(day), intensity \(entry.intensity.map(String.init) ?? "none")"
        }
        return "Day \(day), no wrapup"
    }
}
