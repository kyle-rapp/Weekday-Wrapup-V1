import Foundation

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let entry: CheckInData?
}
