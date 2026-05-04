import Foundation
import SwiftUI
import UIKit

/// FILE: ViewModels/CalendarViewModel.swift
/// Month navigation and selection state for the emotion calendar grid.

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var months: [[CalendarDay]] = []
    @Published var displayedMonth: Date = Date()
    @Published var selectedCalendarDate: Date?
    @Published var selectedEntry: CheckInData?

    private let calendar = Calendar.current
    private var loadedMonthStarts: Set<Date> = []

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
        let displayed = monthStart(for: displayedMonth)
        let current = monthStart(for: Date())
        return calendar.isDate(displayed, equalTo: current, toGranularity: .month)
    }

    func shiftMonth(by value: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = newMonth
        print("📅 MONTH SHIFTED TO:", displayedMonth)
    }

    func generateMonths(entries: [CheckInData], monthsBack: Int = 6) {
        let today = Date()
        loadedMonthStarts.removeAll()
        let sorted = entries.sorted { $0.date > $1.date }
        let chunks: [[CalendarDay]] = (0..<monthsBack).compactMap { offset in
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: today) else { return nil }
            let monthStart = monthStart(for: monthDate)
            loadedMonthStarts.insert(monthStart)
            return generateDays(for: monthDate, entries: sorted)
        }
        months = chunks
    }

    func loadOlderMonths(entries: [CheckInData], batchSize: Int = 6) {
        guard months.count < max(24, batchSize) else { return }
        guard let lastMonth = months.last,
              let lastDate = lastMonth.first?.date,
              let previousMonth = calendar.date(byAdding: .month, value: -1, to: lastDate)
        else { return }

        let previousMonthStart = monthStart(for: previousMonth)
        guard loadedMonthStarts.contains(previousMonthStart) == false else { return }

        let sorted = entries.sorted { $0.date > $1.date }
        let newMonth = generateDays(for: previousMonth, entries: sorted)
        loadedMonthStarts.insert(previousMonthStart)
        months.append(newMonth)
    }

    private func generateDays(for month: Date, entries: [CheckInData]) -> [CalendarDay] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        var days: [CalendarDay] = []

        // Padding ensures Sunday-Saturday alignment for each month.
        for _ in 0..<firstWeekday {
            days.append(CalendarDay(date: firstOfMonth, entry: nil))
        }

        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) else { continue }
            let entry = entries.first { calendar.isDate($0.date, inSameDayAs: date) }
            days.append(CalendarDay(date: date, entry: entry))
        }

        return days
    }

    func monthCells(for month: Date) -> [MonthCell] {
        let comps = calendar.dateComponents([.year, .month], from: month)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        guard let monthStart = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        let firstWeekdayIndex = weekdayOfFirst - calendar.firstWeekday
        let pad = (firstWeekdayIndex % 7 + 7) % 7

        var cells: [MonthCell] = []

        for i in 0..<pad {
            cells.append(MonthCell(id: "pad-\(y)-\(m)-\(i)", dayNumber: nil, dateForDay: nil))
        }

        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            cells.append(MonthCell(id: "day-\(y)-\(m)-\(day)", dayNumber: day, dateForDay: date))
        }

        return cells
    }

    func lookupEntry(for date: Date, entries: [CheckInData]) -> CheckInData? {
        let sameDay = entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
        return sameDay.max(by: { $0.date < $1.date })
    }

    func isSelectedDay(_ date: Date?, selected: Date?) -> Bool {
        guard let sel = selected, let d = date else { return false }
        return calendar.isDate(sel, inSameDayAs: d)
    }

    func selectDay(date: Date, entry: CheckInData?) {
        selectedCalendarDate = date
        selectedEntry = entry
    }

    func clearSelection() {
        selectedCalendarDate = nil
        selectedEntry = nil
    }

    private func monthStart(for date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }
}
