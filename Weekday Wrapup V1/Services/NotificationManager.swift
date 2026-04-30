import Foundation
import UserNotifications

/// FILE: Services/NotificationManager.swift
/// Permission + repeating reminder to check in emotionally.

class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleCheckInReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Check in with yourself"
        content.body = "How are you feeling right now?"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 60 * 60 * 4,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "checkin_reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}
