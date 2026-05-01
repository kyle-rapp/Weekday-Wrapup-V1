import Foundation

/// FILE: Managers/ProfileInsightEngine.swift
/// Short prose insight from onboarding prefs + recent wrapup posts — user must explicitly accept.

enum ProfileInsightEngine {

    static func generateDraft(
        preferredName: String,
        preferences: UserPreferences?,
        recentPosts: [FeedPost]
    ) -> String {
        let joys = preferences?.topJoyActivities
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        let stressors = preferences?.topStressors
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        let joyLine: String = {
            guard joys.count >= 2 else {
                return joys.first.map { "\(preferredName) often feels a lift from \($0.lowercased())." }
                    ?? "\(preferredName) is still building a picture of what helps most."
            }
            let a = joys[0].lowercased()
            let b = joys[1].lowercased()
            return "\(preferredName) tends to feel best when doing things like \(a) and \(b)."
        }()

        let stressLine: String = {
            guard stressors.count >= 2 else {
                return stressors.first.map { "Stress often shows up around \($0.lowercased())." }
                    ?? "Stress patterns will get clearer with a few more honest check-ins."
            }
            return "Stress often clusters around \(stressors[0].lowercased()) and \(stressors[1].lowercased())."
        }()

        let moodFragment = emotionFragment(from: recentPosts)
        let tagsFragment = helpfulTagsFragment(from: recentPosts)

        var parts: [String] = [joyLine, stressLine]
        if let moodFragment { parts.append(moodFragment) }
        if let tagsFragment { parts.append(tagsFragment) }
        return parts.joined(separator: " ")
    }

    private static func emotionFragment(from posts: [FeedPost]) -> String? {
        let labels = posts.flatMap(\.selectedEmotions)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !labels.isEmpty else { return nil }
        let tallies = Dictionary(grouping: labels, by: { $0 }).mapValues(\.count)
        guard let top = tallies.max(by: { $0.value < $1.value })?.key else { return nil }
        return "Lately, \(top.lowercased()) has been showing up a lot in wrapups."
    }

    private static func helpfulTagsFragment(from posts: [FeedPost]) -> String? {
        let tags = posts.flatMap { $0.helpfulTags }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tags.isEmpty else { return nil }
        let tallies = Dictionary(grouping: tags, by: { $0 }).mapValues(\.count)
        guard let top = tallies.max(by: { $0.value < $1.value })?.key else { return nil }
        return "Tags like “\(top)” often mark what helped."
    }
}
