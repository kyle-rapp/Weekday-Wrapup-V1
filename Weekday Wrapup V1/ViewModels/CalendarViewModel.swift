import Foundation

/// FILE: ViewModels/CalendarViewModel.swift
/// Month navigation and selection state for the emotion calendar grid.

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var displayedMonth: Date = Date()
    @Published var selectedCalendarDate: Date?
    @Published var selectedEntry: CheckInData?

    private let calendar = Calendar.current

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

    func shiftMonth(by delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = next
    }

    func monthCells(for displayedMonth: Date) -> [MonthCell] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
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
}
