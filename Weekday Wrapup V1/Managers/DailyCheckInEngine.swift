import Foundation

/// FILE: Managers/DailyCheckInEngine.swift
/// Post check-in pipeline: light NLP-style signals → three recommendation lanes (immediate, habit, resource).

enum DailyEmotionalTrend: String, Equatable {
    case improving
    case declining
    case steady
    case unknown
}

struct DailyCheckInAnalysis: Equatable {
    /// High-level bucket: calm, stressed, overwhelmed, heavy, mixed.
    let emotionalState: String
    let keywords: [String]
    let trend: DailyEmotionalTrend
}

struct DailyRecommendationBundle: Equatable {
    /// Raw primary emotion label from the check-in (for safety routing).
    let checkInEmotion: String
    /// Original check-in text blob (insight/goals) for keyword resource matching.
    let sourceText: String
    let analysis: DailyCheckInAnalysis
    let immediate: Recommendation
    let personalized: Recommendation
    let resource: ResourceRecommendation
}

enum DailyCheckInEngine {

    private static let stopwords: Set<String> = [
        "that", "this", "with", "have", "from", "your", "been", "were", "what", "when", "where",
        "would", "could", "should", "about", "there", "their", "really", "just", "into", "more",
        "some", "than", "them", "then", "very", "also", "only", "even", "much", "such", "will",
        "felt", "feel", "feeling", "week", "today"
    ]

    // MARK: - Public

    static func buildBundle(
        emotion: String,
        intensity: Int,
        journalText: String,
        helpfulTags: [String],
        userPreferences: UserPreferences?,
        weather: RecommendationWeatherHint?
    ) -> DailyRecommendationBundle {
        let analysis = analyze(
            emotion: emotion,
            intensity: intensity,
            journalText: journalText,
            helpfulTags: helpfulTags
        )
        let immediate = generateImmediate(
            analysis: analysis,
            intensity: intensity,
            weather: weather ?? .neutral
        )
        let personalized = generatePersonalized(
            analysis: analysis,
            intensity: intensity,
            preferences: userPreferences,
            helpfulTags: helpfulTags
        )
        let resource = resolveResource(
            emotion: emotion,
            journalText: journalText,
            helpfulTags: helpfulTags,
            stressors: userPreferences?.topStressors ?? []
        )
        return DailyRecommendationBundle(
            checkInEmotion: emotion,
            sourceText: journalText,
            analysis: analysis,
            immediate: immediate,
            personalized: personalized,
            resource: resource
        )
    }

    // MARK: - Step 1 — Analyze

    static func analyze(
        emotion: String,
        intensity: Int,
        journalText: String,
        helpfulTags: [String]
    ) -> DailyCheckInAnalysis {
        let trimmedEmotion = emotion.trimmingCharacters(in: .whitespacesAndNewlines)
        let journal = journalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let blob = ([trimmedEmotion, journal] + helpfulTags).joined(separator: " ").lowercased()

        let emotionalState = classifyEmotionalState(blob: blob, intensity: intensity, emotionLabel: trimmedEmotion.lowercased())
        let keywords = extractKeywords(from: journal)
        let trend = inferTrend(journalLowercased: journal.lowercased(), intensity: intensity)

        return DailyCheckInAnalysis(
            emotionalState: emotionalState,
            keywords: keywords,
            trend: trend
        )
    }

    private static func classifyEmotionalState(blob: String, intensity: Int, emotionLabel: String) -> String {
        if intensity >= 9 || blob.contains("panic") || blob.contains("breaking down") || blob.contains("can't cope") || blob.contains("cannot cope") {
            return "overwhelmed"
        }
        if intensity >= 6 || blob.contains("overwhelm") || blob.contains("stressed") || blob.contains("anxious") || blob.contains("worry") {
            return "stressed"
        }
        if blob.contains("depress") || blob.contains("hopeless") || blob.contains("empty") || blob.contains("grief") || emotionLabel.contains("sad") {
            return "heavy"
        }
        if blob.contains("peace") || blob.contains("calm") || blob.contains("content") || emotionLabel.contains("peaceful") {
            return "calm"
        }
        if blob.contains("angry") || blob.contains("rage") || blob.contains("frustrat") || emotionLabel.contains("mad") {
            return "activated"
        }
        return "mixed"
    }

    private static func extractKeywords(from journal: String) -> [String] {
        let letters = journal.lowercased().split { !$0.isLetter }
        var counts: [String: Int] = [:]
        for word in letters where word.count > 3 {
            let w = String(word)
            guard !stopwords.contains(w) else { continue }
            counts[w, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.prefix(8).map(\.0)
    }

    private static func inferTrend(journalLowercased: String, intensity: Int) -> DailyEmotionalTrend {
        if journalLowercased.contains("better") || journalLowercased.contains("improving") || journalLowercased.contains("lifting") {
            return .improving
        }
        if journalLowercased.contains("worse") || journalLowercased.contains("spiral") || journalLowercased.contains("falling apart") {
            return .declining
        }
        if intensity >= 8 { return .declining }
        if intensity <= 3 && !journalLowercased.isEmpty { return .improving }
        if journalLowercased.isEmpty && intensity == 5 { return .unknown }
        return .steady
    }

    // MARK: - Step 2 — Recommendations

    private static func generateImmediate(
        analysis: DailyCheckInAnalysis,
        intensity: Int,
        weather: RecommendationWeatherHint
    ) -> Recommendation {
        switch analysis.emotionalState {
        case "overwhelmed":
            return Recommendation(
                title: "Box breathing (2 minutes)",
                reason: "When everything feels like too much, a paced breath can soften the nervous system just enough to think clearly again.",
                action: "Start",
                type: .regulation
            )
        case "stressed":
            if weather == .sunny {
                return Recommendation(
                    title: "Step outside for five minutes",
                    reason: "A short change of scene—especially in decent weather—can interrupt stress loops.",
                    action: "Start",
                    type: .action
                )
            }
            return Recommendation(
                title: "Two-minute grounding",
                reason: "Name 3 things you see, 2 you can touch, 1 you can hear. Tiny anchors help when stress runs loud.",
                action: "Try it",
                type: .regulation
            )
        case "heavy":
            return Recommendation(
                title: "One gentle check-in text",
                reason: "You don’t have to explain everything—letting someone know it’s a hard day can ease loneliness a notch.",
                action: "Draft message",
                type: .connection
            )
        case "calm":
            return Recommendation(
                title: "Capture what’s working",
                reason: "A calmer day is data too—one sentence on what helped preserves it for harder weeks.",
                action: "Write a line",
                type: .reflection
            )
        default:
            if intensity >= 7 {
                return Recommendation(
                    title: "Slow the body first",
                    reason: "Higher intensity often means your body needs a downshift before problem-solving.",
                    action: "Breathe",
                    type: .regulation
                )
            }
            return Recommendation(
                title: "Five-minute walk or stretch",
                reason: "Small movement helps most people shift emotional charge without forcing a big decision.",
                action: "Start",
                type: .action
            )
        }
    }

    private static func generatePersonalized(
        analysis: DailyCheckInAnalysis,
        intensity: Int,
        preferences: UserPreferences?,
        helpfulTags: [String]
    ) -> Recommendation {
        if let p = preferences {
            if p.enjoysWalking == true {
                return Recommendation(
                    title: "Walk like you mean it (10 minutes)",
                    reason: "You’ve shared that walking helps—pace doesn’t matter, showing up for yourself does.",
                    action: "Go",
                    type: .action
                )
            }
            if p.callsFriends == true {
                return Recommendation(
                    title: "Call someone who gets you",
                    reason: "You’ve said connection helps—voice notes count if a call feels like a lot.",
                    action: "Reach out",
                    type: .connection
                )
            }
            if p.journals == true {
                return Recommendation(
                    title: "Three-line journal",
                    reason: "Tiny writing beats perfect writing. What happened, what you felt, one kind line back to yourself.",
                    action: "Open notes",
                    type: .reflection
                )
            }
            if p.meditates == true {
                return Recommendation(
                    title: "Guided breath you already trust",
                    reason: "You’ve used meditation before—returning to a short practice meets you where you are.",
                    action: "Breathe",
                    type: .regulation
                )
            }
        }

        if let tag = helpfulTags.first, !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Recommendation(
                title: "Lean on what helped: \(tag)",
                reason: "You tagged this check-in with something that mattered—repeating small wins builds safety.",
                action: "Do it again",
                type: .action
            )
        }

        return Recommendation(
            title: "One micro-kind action",
            reason: "When preferences are still sparse, a tiny act of care (water, snack, fresh air) still counts as emotional skill.",
            action: "Pick one",
            type: .action
        )
    }

    private static func resolveResource(
        emotion: String,
        journalText: String,
        helpfulTags: [String],
        stressors: [String]
    ) -> ResourceRecommendation {
        let tags = ([emotion] + helpfulTags + stressors).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return RecommendationResourceEngine.bestResource(
            postText: journalText,
            emotionTags: tags,
            stressors: stressors
        )
    }
}
