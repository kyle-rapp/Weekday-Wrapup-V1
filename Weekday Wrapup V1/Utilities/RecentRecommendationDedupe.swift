import Foundation

/// FILE: Utilities/RecentRecommendationDedupe.swift
/// Avoid showing the same recommendation title within 24 hours.

enum RecentRecommendationDedupe {
    private static let key = "recentRecommendationTitleHistory"
    private static let windowSeconds: TimeInterval = 24 * 60 * 60

    private struct Entry: Codable {
        var titleLowercased: String
        var seenAt: TimeInterval
    }

    static func excludedTitles(now: Date = Date()) -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: key),
              var list = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        let cutoff = now.timeIntervalSince1970 - windowSeconds
        list.removeAll { $0.seenAt < cutoff }
        if let encoded = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
        return Set(list.map(\.titleLowercased))
    }

    static func recordShownTitles(_ titles: [String], now: Date = Date()) {
        let t = now.timeIntervalSince1970
        var existing: [Entry] = {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
            return decoded
        }()
        let cutoff = t - windowSeconds
        existing.removeAll { $0.seenAt < cutoff }
        for title in titles {
            let low = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !low.isEmpty else { continue }
            existing.append(Entry(titleLowercased: low, seenAt: t))
        }
        if let encoded = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
