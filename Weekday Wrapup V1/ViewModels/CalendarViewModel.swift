import Foundation
import SwiftUI
import UIKit

/// FILE: ViewModels/CalendarViewModel.swift
/// Month navigation and selection state for the emotion calendar grid.

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var months: [[CalendarDay]] = []
    @Published private(set) var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    @Published var selectedCalendarDate: Date?
    @Published var selectedEntry: CheckInData?

    private let calendar = Calendar.current
    private var loadedMonthStarts: Set<Date> = []

    init() {}

    struct MonthCell: Identifiable, Equatable {
        let id: String
        let dayNumber: Int?
        let dateForDay: Date?
    }

    /// Weekday symbols aligned to grid columns (respects locale `firstWeekday`).
    var weekdayHeaderSymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        return (0..<7).map { col in
            let idx = (calendar.firstWeekday - 1 + col) % 7
            return symbols[idx]
        }
    }

    var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    var isCurrentMonth: Bool {
        let displayed = calendar.startOfMonth(for: displayedMonth)
        let current = calendar.startOfMonth(for: Date())
        return calendar.isDate(displayed, equalTo: current, toGranularity: .month)
    }

    func shiftMonth(by value: Int) {
        let currentMonth = calendar.startOfMonth(for: displayedMonth)
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) else { return }
        displayedMonth = calendar.startOfMonth(for: newMonth)
    }

    func generateMonths(entries: [CheckInData], monthsBack: Int = 6) {
        let currentMonth = calendar.startOfMonth(for: Date())
        loadedMonthStarts.removeAll()
        let sorted = entries.sorted { $0.date > $1.date }
        let chunks: [[CalendarDay]] = (0..<monthsBack).compactMap { offset in
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: currentMonth) else { return nil }
            let monthStart = calendar.startOfMonth(for: monthDate)
            loadedMonthStarts.insert(monthStart)
            return generateDays(for: monthStart, entries: sorted)
        }
        months = chunks
    }

    func loadOlderMonths(entries: [CheckInData], batchSize: Int = 6) {
        guard months.count < max(24, batchSize) else { return }
        guard let lastMonth = months.last,
              let lastDate = lastMonth.first?.date,
              let previousMonth = calendar.date(byAdding: .month, value: -1, to: lastDate)
        else { return }

        let previousMonthStart = calendar.startOfMonth(for: previousMonth)
        guard loadedMonthStarts.contains(previousMonthStart) == false else { return }

        let sorted = entries.sorted { $0.date > $1.date }
        let newMonth = generateDays(for: previousMonthStart, entries: sorted)
        loadedMonthStarts.insert(previousMonthStart)
        months.append(newMonth)
    }

    private func generateDays(for month: Date, entries: [CheckInData]) -> [CalendarDay] {
        let normalizedMonth = calendar.startOfMonth(for: month)
        guard let range = calendar.range(of: .day, in: .month, for: normalizedMonth),
              let firstOfMonthRaw = calendar.date(from: calendar.dateComponents([.year, .month], from: normalizedMonth))
        else { return [] }
        let firstOfMonth = calendar.startOfMonth(for: firstOfMonthRaw)

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        var days: [CalendarDay] = []

        // Padding ensures Sunday-Saturday alignment for each month.
        for _ in 0..<firstWeekday {
            days.append(CalendarDay(date: firstOfMonth, entry: nil))
        }

        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) else { continue }
            let normalizedDate = calendar.startOfDay(for: date)
            let entry = entries.first {
                calendar.isDate(calendar.startOfDay(for: $0.date), inSameDayAs: normalizedDate)
            }
            days.append(CalendarDay(date: normalizedDate, entry: entry))
        }

        return days
    }

    func monthCells(for month: Date) -> [MonthCell] {
        let monthStart = calendar.startOfMonth(for: month)

        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        let firstWeekdayIndex = weekdayOfFirst - calendar.firstWeekday
        let pad = (firstWeekdayIndex % 7 + 7) % 7

        var cells: [MonthCell] = []

        for i in 0..<pad {
            cells.append(MonthCell(
                id: "pad-\(monthStart)-\(i)",
                dayNumber: nil,
                dateForDay: nil
            ))
        }

        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            let normalized = calendar.startOfDay(for: date)
            cells.append(MonthCell(
                id: "day-\(normalized)",
                dayNumber: day,
                dateForDay: normalized
            ))
        }

        return cells
    }

    func lookupEntry(for date: Date, entries: [CheckInData]) -> CheckInData? {
        let normalized = calendar.startOfDay(for: date)

        return entries.first {
            calendar.isDate(calendar.startOfDay(for: $0.date), inSameDayAs: normalized)
        }
    }

    func isSelectedDay(_ date: Date?, selected: Date?) -> Bool {
        guard let sel = selected, let d = date else { return false }
        return calendar.isDate(sel, inSameDayAs: d)
    }

    func selectDay(date: Date, entry: CheckInData?) {
        selectedCalendarDate = calendar.startOfDay(for: date)
        selectedEntry = entry
    }

    func clearSelection() {
        selectedCalendarDate = nil
        selectedEntry = nil
    }

}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return startOfDay(for: self.date(from: comps) ?? date)
    }
}
