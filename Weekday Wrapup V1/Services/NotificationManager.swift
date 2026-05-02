import Foundation
import UserNotifications

/// FILE: Services/NotificationManager.swift
/// Permission + repeating reminder to check in emotionally.

class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleCheckInReminder() {
        scheduleMissedCheckInReminder(hour: 20)
    }

    func scheduleMissedCheckInReminder(hour: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Check in with yourself"
        content.body = "A quick check-in can make tomorrow easier."
        scheduleDaily(identifier: "checkin_missed_subtle", content: content, hour: hour)
    }

    func scheduleStreakGapReminder(hour: Int = 12) {
        let content = UNMutableNotificationContent()
        content.title = "Keep your emotional streak gentle"
        content.body = "One small check-in keeps your reflection loop going."
        scheduleDaily(identifier: "streak_gap_subtle", content: content, hour: hour)
    }

    func scheduleMeaningfulFriendActivityReminder(hour: Int = 18) {
        let content = UNMutableNotificationContent()
        content.title = "Someone in your circle shared today"
        content.body = "A simple reaction or invite can mean a lot."
        scheduleDaily(identifier: "friend_activity_subtle", content: content, hour: hour)
    }

    func clearScheduledReminders() {
        center.removePendingNotificationRequests(withIdentifiers: [
            "checkin_missed_subtle",
            "streak_gap_subtle",
            "friend_activity_subtle"
        ])
    }

    private func scheduleDaily(identifier: String, content: UNMutableNotificationContent, hour: Int) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        var components = DateComponents()
        components.hour = min(23, max(0, hour))
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }
}
