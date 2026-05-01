import Foundation

/// FILE: Utilities/InviteRateLimiter.swift
/// Simple per-day cap on activity invites (client-side; pair with trusted-device UX).

enum InviteRateLimiter {
    private static let maxPerDay = 12
    private static let dayKey = "softSocialInviteRateDay"
    private static let countKey = "softSocialInviteRateCount"

    private static var calendar: Calendar { .current }

    private static func dayStamp(_ date: Date) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSince1970)
    }

    static func canSendInvite() -> Bool {
        let today = dayStamp(Date())
        let stored = UserDefaults.standard.integer(forKey: dayKey)
        let count = UserDefaults.standard.integer(forKey: countKey)
        if stored != today { return true }
        return count < maxPerDay
    }

    static func recordInviteSent() {
        let today = dayStamp(Date())
        let stored = UserDefaults.standard.integer(forKey: dayKey)
        if stored != today {
            UserDefaults.standard.set(today, forKey: dayKey)
            UserDefaults.standard.set(1, forKey: countKey)
        } else {
            let n = UserDefaults.standard.integer(forKey: countKey)
            UserDefaults.standard.set(n + 1, forKey: countKey)
        }
    }

    static var invitesRemainingToday: Int {
        let today = dayStamp(Date())
        let stored = UserDefaults.standard.integer(forKey: dayKey)
        if stored != today { return maxPerDay }
        return max(0, maxPerDay - UserDefaults.standard.integer(forKey: countKey))
    }
}
