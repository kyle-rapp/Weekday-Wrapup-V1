import Foundation

/// FILE: ViewModels/GrowViewModel.swift
/// Insights, filtering, and personalized recommendations for the Grow tab.

@MainActor
final class GrowViewModel: ObservableObject {
    /// All wrapup-derived entries for the current user (unfiltered).
    @Published private(set) var entries: [CheckInData] = []

    /// Emotion chip filter; `nil` means show all.
    @Published var selectedEmotion: String?

    /// Saved personalization profile (optional).
    @Published private(set) var userPreferences: UserPreferences?

    /// Cached personalized cards (2–3 items).
    @Published private(set) var personalizedRecommendations: [Recommendation] = []

    private let recommendationEngine = PersonalizedRecommendationEngine()
    private var recommendationCacheSignature: String = ""

    func syncEntries(_ list: [CheckInData]) {
        entries = list
        invalidateRecommendationCache()
    }

    func setUserPreferences(_ preferences: UserPreferences?) {
        userPreferences = preferences
        invalidateRecommendationCache()
    }

    func invalidateRecommendationCache() {
        recommendationCacheSignature = ""
    }

    /// Recomputes recommendations only when inputs change (performance).
    func refreshPersonalizedRecommendations(weather: RecommendationWeatherHint) {
        let history = filteredEntries
        let (emotion, intensity, tags) = PersonalizedRecommendationEngine.moodContext(from: history)
        let sig = [
            emotion,
            "\(intensity)",
            tags.joined(separator: ","),
            userPreferences.map { String(describing: $0) } ?? "nil",
            weather.rawValue,
            "\(history.count)",
            selectedEmotion ?? "_all"
        ].joined(separator: "|")

        guard sig != recommendationCacheSignature else { return }
        recommendationCacheSignature = sig

        personalizedRecommendations = recommendationEngine.generate(
            emotion: emotion,
            intensity: intensity,
            tags: tags,
            preferences: userPreferences,
            history: history,
            weather: weather
        )
    }

    // MARK: - Filtered data

    var filteredEntries: [CheckInData] {
        guard let raw = selectedEmotion?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return entries
        }
        return entries.filter { entry in
            entry.selectedEmotions.contains { $0.caseInsensitiveCompare(raw) == .orderedSame }
        }
    }

    var topEmotions: [String] {
        let flat = entries.flatMap { Array($0.selectedEmotions) }
        let counts = Dictionary(grouping: flat, by: { $0 }).mapValues(\.count)
        return counts.sorted { $0.value > $1.value }.prefix(8).map(\.key)
    }

    var emotionTrendCounts: [String: Int] {
        let flat = filteredEntries.flatMap { Array($0.selectedEmotions) }
        return Dictionary(grouping: flat, by: { $0 }).mapValues(\.count)
    }

    var mostCommonEmotion: String {
        let labels = filteredEntries.flatMap { Array($0.selectedEmotions) }
        guard !labels.isEmpty else { return "—" }
        let counts = Dictionary(grouping: labels, by: { $0 }).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key ?? "—"
    }

    var averageIntensity: String {
        let ints = filteredEntries.compactMap(\.intensity)
        guard !ints.isEmpty else { return "—" }
        let avg = Double(ints.reduce(0, +)) / Double(ints.count)
        return String(format: "%.1f", avg)
    }

    var topHelpfulTag: String? {
        let tags = entries.flatMap { $0.helpfulTags ?? [] }
        guard !tags.isEmpty else { return nil }
        let counts = Dictionary(grouping: tags, by: { $0 }).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key
    }

    var topHelpfulTagLine: String? {
        guard let top = topHelpfulTag else { return nil }
        return "You feel better most often after: \(top)"
    }

    var helpfulTagCounts: [String: Int] {
        let tags = entries.flatMap { $0.helpfulTags ?? [] }
        return Dictionary(grouping: tags, by: { $0 }).mapValues(\.count)
    }

    var insightText: String {
        Self.generateInsight(from: filteredEntries)
    }

    /// Legacy single-line copy (e.g. widgets); mirrors first personalized card when possible.
    var recommendationText: String {
        if let first = personalizedRecommendations.first {
            return "\(first.title) — \(first.reason)"
        }
        return "Keep checking in; your next insight will land here."
    }

    func entry(on day: Date, calendar: Calendar = .current) -> CheckInData? {
        filteredEntries
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .max(by: { $0.date < $1.date })
    }

    private static func generateInsight(from entries: [CheckInData]) -> String {
        let recent = Array(entries.suffix(5))
        let ints = recent.compactMap(\.intensity)
        guard !ints.isEmpty else {
            return "You're in a steady place. Keep building small habits."
        }
        let avg = Double(ints.reduce(0, +)) / Double(ints.count)

        if avg >= 7 {
            return "You've been feeling intense lately. Try slowing down today."
        } else if avg <= 3 {
            return "Things seem lighter recently. Notice what's helping."
        } else {
            return "You're in a steady place. Keep building small habits."
        }
    }
}
