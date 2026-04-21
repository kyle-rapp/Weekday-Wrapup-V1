import Foundation

/// FILE: Utilities/RelativeTimeFormat.swift
/// Short relative strings for feed timestamps (e.g. “2h ago”).

enum RelativeTimeFormat {
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    static func string(for date: Date?, relativeTo now: Date = Date()) -> String {
        guard let date else { return "—" }
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
