import Foundation

/// FILE: Managers/EmotionPersonalizationEngine.swift
/// Thin orchestrator that unifies recommendation decisions across app surfaces.

enum RecommendationSurface: String, CaseIterable, Hashable {
    case growTab
    case checkInPopup
    case dopamineMenu
    case postDetail
}

struct EmotionContext {
    let emotion: String
    let intensity: Int
    let journalText: String
    let helpfulTags: [String]
    let userPreferences: UserPreferences?
    let history: [CheckInData]
    let weather: RecommendationWeatherHint
    let feedbackRows: [(title: String, helpful: Bool)]
    let memory: [String: RecommendationMemory]
    let habitInsights: [HabitInsight]
    let stressors: [String]
    let adaptiveProfile: UserAdaptiveProfile?

    init(
        emotion: String,
        intensity: Int,
        journalText: String = "",
        helpfulTags: [String] = [],
        userPreferences: UserPreferences?,
        history: [CheckInData],
        weather: RecommendationWeatherHint = .neutral,
        feedbackRows: [(title: String, helpful: Bool)] = [],
        memory: [String: RecommendationMemory] = [:],
        habitInsights: [HabitInsight] = [],
        stressors: [String] = [],
        adaptiveProfile: UserAdaptiveProfile? = nil
    ) {
        self.emotion = emotion
        self.intensity = max(1, min(10, intensity))
        self.journalText = journalText
        self.helpfulTags = helpfulTags
        self.userPreferences = userPreferences
        self.history = history
        self.weather = weather
        self.feedbackRows = feedbackRows
        self.memory = memory
        self.habitInsights = habitInsights
        self.stressors = stressors
        self.adaptiveProfile = adaptiveProfile
    }

    static func fromHistory(
        _ history: [CheckInData],
        userPreferences: UserPreferences?,
        weather: RecommendationWeatherHint,
        feedbackRows: [(title: String, helpful: Bool)],
        memory: [String: RecommendationMemory],
        habitInsights: [HabitInsight],
        adaptiveProfile: UserAdaptiveProfile? = nil
    ) -> EmotionContext {
        let (emotion, intensity, tags) = PersonalizedRecommendationEngine.moodContext(from: history)
        return EmotionContext(
            emotion: emotion,
            intensity: intensity,
            helpfulTags: tags,
            userPreferences: userPreferences,
            history: history,
            weather: weather,
            feedbackRows: feedbackRows,
            memory: memory,
            habitInsights: habitInsights,
            stressors: userPreferences?.topStressors ?? [],
            adaptiveProfile: adaptiveProfile
        )
    }
}

struct UserEmotionProfile {
    let calmBoostActivities: Set<String>
    let stressReliefActivities: Set<String>
    let positiveEmotionBoosters: Set<String>
    let dopamineMenuActivities: Set<String>
    let recentEffectiveActivities: [String: Date]
}

final class EmotionPersonalizationEngine {
    private let personalized = PersonalizedRecommendationEngine()
    private let firestore: FirestoreManager?
    private let userIdProvider: (() -> String?)?

    /// Last recommendation/context cache used for feedback routing.
    private var recommendationById: [String: Recommendation] = [:]
    private var contextBySurface: [RecommendationSurface: EmotionContext] = [:]

    init(
        firestore: FirestoreManager? = nil,
        userIdProvider: (() -> String?)? = nil
    ) {
        self.firestore = firestore
        self.userIdProvider = userIdProvider
    }

    func getRecommendations(
        context: EmotionContext,
        surface: RecommendationSurface
    ) -> [Recommendation] {
        #if DEBUG
        print("[GROW_STABILITY] getRecommendations surface=\(surface.rawValue) emotion=\(context.emotion) intensity=\(context.intensity) history=\(context.history.count)")
        #endif
        let excluded = (surface == .growTab) ? RecentRecommendationDedupe.excludedTitles() : []

        let personalizedRecs = personalized.generate(
            emotion: context.emotion,
            intensity: context.intensity,
            tags: context.helpfulTags,
            preferences: context.userPreferences,
            history: context.history,
            weather: context.weather,
            feedbackRows: context.feedbackRows,
            excludedTitlesLowercased: excluded,
            memory: context.memory,
            habitInsights: context.habitInsights
        )

        let dailyBundle = DailyCheckInEngine.buildBundle(
            emotion: context.emotion,
            intensity: context.intensity,
            journalText: context.journalText,
            helpfulTags: context.helpfulTags,
            userPreferences: context.userPreferences,
            weather: context.weather
        )

        var candidates: [(recommendation: Recommendation, sourceBoost: Double)] = []
        candidates.append(contentsOf: personalizedRecs.map { ($0, 1.0) })
        candidates.append((dailyBundle.immediate, 0.85))
        candidates.append((dailyBundle.personalized, 0.65))

        // Map best matching resource into a recommendation-shaped card for unified ranking.
        let bestResource = RecommendationResourceEngine.bestResource(
            postText: context.journalText,
            emotionTags: [context.emotion] + context.helpfulTags,
            stressors: context.stressors
        )
        let resourceCard = Recommendation(
            title: bestResource.title,
            reason: bestResource.summary,
            action: "Open resource",
            type: .action,
            resourceURL: bestResource.url,
            tags: ["resource", "support"] + bestResource.tags,
            emotionTargets: [context.emotion.lowercased()],
            intensityRange: 1 ... 10
        )
        candidates.append((resourceCard, 0.5))

        let deduped = dedupeByTitleKeepingBest(candidates)
        let userProfile = buildUserProfile(from: context)
        let ranked = rankRecommendations(
            deduped.map(\.recommendation),
            context: context,
            userProfile: userProfile
        )
        let filtered = applySafetyAndSurfaceFilters(
            ranked,
            allCandidates: deduped.map(\.recommendation),
            context: context,
            surface: surface
        )
        let limited = Array(uniqueById(filtered).prefix(maxCount(for: surface)))
        for rec in limited {
            recommendationById[rec.id.uuidString] = rec
        }
        contextBySurface[surface] = context
        return limited
    }

    /// Wrapper entry point for existing check-in popup flow.
    func buildCheckInBundle(context: EmotionContext) -> DailyRecommendationBundle {
        let base = DailyCheckInEngine.buildBundle(
            emotion: context.emotion,
            intensity: context.intensity,
            journalText: context.journalText,
            helpfulTags: context.helpfulTags,
            userPreferences: context.userPreferences,
            weather: context.weather
        )
        let surfaced = getRecommendations(context: context, surface: .checkInPopup)
        let immediate = surfaced.first ?? base.immediate
        let personalized = surfaced.dropFirst().first ?? base.personalized
        return DailyRecommendationBundle(
            checkInEmotion: base.checkInEmotion,
            intensity: base.intensity,
            sourceText: base.sourceText,
            analysis: base.analysis,
            immediate: immediate,
            personalized: personalized,
            resource: base.resource
        )
    }

    func emotionPolarity(for emotion: String) -> EmotionPolarity {
        DailyCheckInEngine.polarity(for: emotion)
    }

    func recordFeedback(
        recommendationId: String,
        didHelp: Bool,
        source: RecommendationSurface
    ) {
        guard let firestore, let userId = userIdProvider?() else { return }

        let rec = recommendationById[recommendationId]
        let context = contextBySurface[source]
        Task {
            let stream = EmotionalEventStreamService(firestore: firestore)
            let eventSource: EventSource = {
                switch source {
                case .growTab: return .growTab
                case .checkInPopup: return .checkInPopup
                case .dopamineMenu: return .dopamineMenu
                case .postDetail: return .feed
                }
            }()
            if let rec {
                let before = context.map { EmotionSnapshot(emotion: $0.emotion, intensity: Double($0.intensity)) }
                await stream.logRecommendationInteraction(
                    userId: userId,
                    recommendation: rec,
                    actionType: didHelp ? .complete : .dismiss,
                    source: eventSource,
                    didHelp: didHelp,
                    emotionBefore: before,
                    emotionAfter: nil,
                    metadata: ["engine": "EmotionPersonalizationEngine"]
                )

                if didHelp, let context {
                    let signal = HabitSignal(
                        userId: userId,
                        actionType: HabitReinforcementEngine.normalizeActionType(rec.type.rawValue),
                        emotionBefore: context.emotion,
                        emotionAfter: nil,
                        intensityBefore: context.intensity,
                        intensityAfter: nil,
                        createdAt: Date()
                    )
                    await stream.logHabitSignal(userId: userId, signal: signal, source: eventSource, metadata: ["origin": "recommendation_feedback"])
                }
            } else {
                AppLogger.error("EmotionPersonalizationEngine feedback routing missing recommendation for id=\(recommendationId)")
            }
        }
    }

    private func maxCount(for surface: RecommendationSurface) -> Int {
        switch surface {
        case .checkInPopup: return 2
        case .dopamineMenu: return 6
        case .growTab: return 5
        case .postDetail: return 3
        }
    }

    private func rankRecommendations(
        _ recommendations: [Recommendation],
        context: EmotionContext,
        userProfile: UserEmotionProfile
    ) -> [Recommendation] {
        recommendations
            .map { ($0, scoreRecommendation($0, context: context, userProfile: userProfile)) }
            .sorted {
                if abs($0.1 - $1.1) > 0.0001 {
                    return $0.1 > $1.1
                }
                return $0.0.title.localizedCaseInsensitiveCompare($1.0.title) == .orderedAscending
            }
            .map(\.0)
    }

    func scoreRecommendation(
        _ recommendation: Recommendation,
        context: EmotionContext,
        userProfile: UserEmotionProfile
    ) -> Double {
        let emotionalFit = emotionalFitScore(recommendation, emotion: context.emotion)
        let historicalHelp = historicalHelpScore(recommendation, context: context, userProfile: userProfile)
        let effortFit = effortFitScore(recommendation, intensity: context.intensity)
        let recencyBoost = recencyBoostScore(recommendation, userProfile: userProfile)
        let contextSafetyWeight = contextSafetyWeight(for: recommendation, context: context)
        let adaptiveHelpfulBoost = adaptiveHelpfulBoost(for: recommendation, profile: context.adaptiveProfile)
        let adaptiveRiskPenalty = adaptiveRiskPenalty(for: recommendation, profile: context.adaptiveProfile)
        let adaptiveCategoryBoost = adaptiveCategoryBoost(for: recommendation, profile: context.adaptiveProfile)
        let adaptiveContextBoost = adaptiveContextBoost(for: context, profile: context.adaptiveProfile)

        return
            emotionalFit * 0.35
            + historicalHelp * 0.30
            + effortFit * 0.20
            + recencyBoost * 0.10
            + contextSafetyWeight * 0.05
            + adaptiveHelpfulBoost
            + adaptiveCategoryBoost
            + adaptiveContextBoost
            - adaptiveRiskPenalty
    }

    private func emotionalFitScore(_ rec: Recommendation, emotion: String) -> Double {
        let family = emotionFamily(for: emotion)
        switch family {
        case .sadness:
            if isGroundingRecommendation(rec) || rec.type == .connection { return 1.0 }
            if rec.type == .reflection { return 0.7 }
            return 0.4
        case .anxiety:
            if isGroundingRecommendation(rec) || containsAny(rec, keywords: ["safety", "structure", "slow"]) { return 1.0 }
            if rec.type == .regulation { return 0.9 }
            if rec.type == .reflection { return 0.6 }
            return 0.35
        case .anger:
            if containsAny(rec, keywords: ["walk", "movement", "cool", "pause", "breathe"]) { return 1.0 }
            if rec.type == .action || rec.type == .regulation { return 0.8 }
            return 0.45
        case .joy:
            if containsAny(rec, keywords: ["capture", "journal", "share", "repeat"]) { return 1.0 }
            if rec.type == .reflection || rec.type == .connection { return 0.8 }
            return 0.5
        case .peaceful:
            if containsAny(rec, keywords: ["maintain", "gentle", "walk", "reflect"]) { return 1.0 }
            if rec.type == .reflection || rec.type == .action { return 0.75 }
            return 0.5
        case .powerful:
            if containsAny(rec, keywords: ["create", "build", "plan", "action", "express"]) { return 1.0 }
            if rec.type == .action || rec.type == .reflection { return 0.75 }
            return 0.45
        case .unknown:
            return rec.type == .regulation ? 0.75 : 0.55
        }
    }

    private func historicalHelpScore(
        _ rec: Recommendation,
        context: EmotionContext,
        userProfile: UserEmotionProfile
    ) -> Double {
        let key = recommendationActivityKey(rec)
        var score = 0.0

        if userProfile.calmBoostActivities.contains(key) { score += 0.35 }
        if userProfile.stressReliefActivities.contains(key) { score += 0.30 }
        if userProfile.positiveEmotionBoosters.contains(key) { score += 0.25 }
        if userProfile.dopamineMenuActivities.contains(key) { score += 0.10 }

        if let memory = context.memory[rec.id.uuidString] {
            let accepted = Double(memory.timesAccepted)
            let dismissed = Double(memory.timesDismissed)
            let total = max(1.0, accepted + dismissed)
            let acceptanceRatio = accepted / total
            score += acceptanceRatio * 0.20
        }

        return min(1.0, score)
    }

    private func effortFitScore(_ rec: Recommendation, intensity: Int) -> Double {
        let level = effortLevel(for: rec)
        let intensityWeight = contextIntensityWeight(intensity)
        switch intensityWeight {
        case .high:
            switch level {
            case .low: return 1.0
            case .medium: return 0.45
            case .high: return 0.10
            }
        case .medium:
            switch level {
            case .low: return 0.8
            case .medium: return 0.75
            case .high: return 0.35
            }
        case .low:
            switch level {
            case .low: return 0.65
            case .medium: return 0.80
            case .high: return 0.90
            }
        }
    }

    private func recencyBoostScore(_ rec: Recommendation, userProfile: UserEmotionProfile) -> Double {
        let key = recommendationActivityKey(rec)
        guard let lastDate = userProfile.recentEffectiveActivities[key] else { return 0.2 }
        let ageDays = Date().timeIntervalSince(lastDate) / 86_400.0
        let decay = exp(-ageDays / 7.0) // Mild decay over about a week
        return min(1.0, 0.2 + decay * 0.8)
    }

    private func contextSafetyWeight(for rec: Recommendation, context: EmotionContext) -> Double {
        if isHighDistressContext(context) {
            if isGroundingRecommendation(rec) { return 1.0 }
            if isLowEffort(rec), !isSocialPressure(rec) { return 0.75 }
            return 0.0
        }
        if context.intensity >= 7 {
            return isLowEffort(rec) ? 0.85 : 0.35
        }
        return 0.75
    }

    private func applySafetyAndSurfaceFilters(
        _ ranked: [Recommendation],
        allCandidates: [Recommendation],
        context: EmotionContext,
        surface: RecommendationSurface
    ) -> [Recommendation] {
        var filtered = ranked

        if isHighDistressContext(context) {
            filtered = filtered.filter { isLowEffort($0) && isGroundingRecommendation($0) && !isSocialPressure($0) }
            if filtered.isEmpty {
                filtered = allCandidates.filter { isLowEffort($0) && isGroundingRecommendation($0) }
            }
        }

        if surface == .checkInPopup {
            let lowEffortOnly = filtered.filter { isLowEffort($0) && !isSocialPressure($0) }
            filtered = lowEffortOnly.isEmpty ? filtered : lowEffortOnly
        }

        if surface == .dopamineMenu {
            // Keep dopamine suggestions practical and repeatable.
            filtered = filtered.filter { !$0.title.lowercased().contains("crisis") }
            if let profile = context.adaptiveProfile,
               profile.unhealthyPatternScores["dessert_saturation", default: 0] > 0.5 {
                filtered = filtered.sorted { lhs, rhs in
                    let leftDessertPenalty = isDessertLike(lhs) ? 1 : 0
                    let rightDessertPenalty = isDessertLike(rhs) ? 1 : 0
                    return leftDessertPenalty < rightDessertPenalty
                }
            }
        }

        return filtered
    }

    private func uniqueById(_ recommendations: [Recommendation]) -> [Recommendation] {
        var seen = Set<String>()
        var out: [Recommendation] = []
        for rec in recommendations {
            let id = rec.id.uuidString
            guard seen.insert(id).inserted else { continue }
            out.append(rec)
        }
        return out
    }

    private func dedupeByTitleKeepingBest(
        _ candidates: [(recommendation: Recommendation, sourceBoost: Double)]
    ) -> [(recommendation: Recommendation, sourceBoost: Double)] {
        var bestByTitle: [String: (recommendation: Recommendation, sourceBoost: Double)] = [:]
        for candidate in candidates {
            let key = candidate.recommendation.title.lowercased()
            let existing = bestByTitle[key]
            if existing == nil || candidate.sourceBoost > (existing?.sourceBoost ?? 0) {
                bestByTitle[key] = candidate
            }
        }
        return bestByTitle
            .values
            .sorted { lhs, rhs in
                if lhs.sourceBoost != rhs.sourceBoost {
                    return lhs.sourceBoost > rhs.sourceBoost
                }
                return lhs.recommendation.title.localizedCaseInsensitiveCompare(rhs.recommendation.title) == .orderedAscending
            }
    }

    private func buildUserProfile(from context: EmotionContext) -> UserEmotionProfile {
        let family = emotionFamily(for: context.emotion)
        var calm = Set<String>()
        var stress = Set<String>()
        var positive = Set<String>()
        var recent: [String: Date] = [:]

        let sortedHistory = context.history.sorted { $0.date > $1.date }
        for entry in sortedHistory {
            let keys = activityKeys(from: entry)
            for key in keys {
                if recent[key] == nil {
                    recent[key] = entry.date
                }
            }

            let entryFamily = emotionFamily(for: entry.firstSelectedEmotionLabel)
            switch entryFamily {
            case .joy, .peaceful, .powerful:
                positive.formUnion(keys)
                if (entry.intensity ?? 5) <= 4 {
                    calm.formUnion(keys)
                }
            case .sadness, .anxiety, .anger:
                stress.formUnion(keys)
                if (entry.intensity ?? 5) <= 4 {
                    calm.formUnion(keys)
                }
            case .unknown:
                break
            }
        }

        let normalizedHelpful = Set(context.helpfulTags.map(normalizeText))
        switch family {
        case .joy, .peaceful, .powerful:
            positive.formUnion(normalizedHelpful)
        case .sadness, .anxiety, .anger:
            stress.formUnion(normalizedHelpful)
        case .unknown:
            calm.formUnion(normalizedHelpful)
        }

        return UserEmotionProfile(
            calmBoostActivities: calm,
            stressReliefActivities: stress,
            positiveEmotionBoosters: positive,
            dopamineMenuActivities: normalizedHelpful,
            recentEffectiveActivities: recent
        )
    }

    private func activityKeys(from entry: CheckInData) -> Set<String> {
        var keys = Set((entry.helpfulTags ?? []).map(normalizeText))
        let helper = normalizeText(entry.whatHelped ?? "")
        if !helper.isEmpty { keys.insert(helper) }
        for action in HabitReinforcementEngine.actionTypes(from: entry) {
            keys.insert(normalizeText(action))
        }
        return keys
    }

    private func recommendationActivityKey(_ rec: Recommendation) -> String {
        if let firstTag = rec.tags.first {
            return normalizeText(firstTag)
        }
        return normalizeText(rec.title)
    }

    private func adaptiveHelpfulBoost(for rec: Recommendation, profile: UserAdaptiveProfile?) -> Double {
        guard let profile else { return 0 }
        let key = recommendationActivityKey(rec)
        return clamp(profile.helpfulActivityScores[key, default: 0] * 0.08, min: -0.08, max: 0.12)
    }

    private func adaptiveRiskPenalty(for rec: Recommendation, profile: UserAdaptiveProfile?) -> Double {
        guard let profile else { return 0 }
        let key = recommendationActivityKey(rec)
        let risk = profile.unhealthyPatternScores[key, default: 0]
            + (isDessertLike(rec) ? profile.unhealthyPatternScores["dessert_saturation", default: 0] * 0.5 : 0)
            + (isDoomScrollingLike(rec) ? profile.unhealthyPatternScores["doom_scrolling_pattern", default: 0] : 0)
        return clamp(risk * 0.10, min: 0, max: 0.25)
    }

    private func adaptiveCategoryBoost(for rec: Recommendation, profile: UserAdaptiveProfile?) -> Double {
        guard let profile else { return 0 }
        let category = dopamineCategoryForRecommendation(rec).lowercased()
        return clamp(profile.categoryAffinities[category, default: 0] * 0.06, min: -0.08, max: 0.10)
    }

    private func adaptiveContextBoost(for context: EmotionContext, profile: UserAdaptiveProfile?) -> Double {
        guard let profile else { return 0 }
        let key = adaptiveContextKey(context: context)
        return clamp(profile.emotionalContextScores[key, default: 0] * 0.05, min: -0.06, max: 0.08)
    }

    private func adaptiveContextKey(context: EmotionContext) -> String {
        let emotion = context.emotion.lowercased()
        let intensityBand: String = {
            if context.intensity >= 7 { return "high" }
            if context.intensity >= 4 { return "medium" }
            return "low"
        }()
        let hour = Calendar.current.component(.hour, from: Date())
        let bucket: String
        switch hour {
        case 5..<12: bucket = "morning"
        case 12..<17: bucket = "afternoon"
        case 17..<22: bucket = "evening"
        default: bucket = "night"
        }
        return "\(emotion)|\(intensityBand)|\(bucket)|adaptive"
    }

    private func dopamineCategoryForRecommendation(_ rec: Recommendation) -> String {
        if isDessertLike(rec) { return "dessert" }
        switch rec.type {
        case .regulation: return "appetizer"
        case .action: return "entree"
        case .reflection: return "side"
        case .connection: return "special"
        }
    }

    private func isDessertLike(_ rec: Recommendation) -> Bool {
        let text = "\(rec.title) \(rec.reason) \(rec.tags.joined(separator: " "))".lowercased()
        return containsAny(text, keywords: [
            "social media", "scroll", "short-form", "youtube", "video apps", "memes", "shopping apps", "random internet"
        ])
    }

    private func isDoomScrollingLike(_ rec: Recommendation) -> Bool {
        let text = "\(rec.title) \(rec.reason) \(rec.tags.joined(separator: " "))".lowercased()
        return containsAny(text, keywords: [
            "doom", "scroll", "tiktok", "instagram", "x", "twitter", "facebook", "youtube"
        ])
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }

    private func normalizeText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "  ", with: " ")
    }

    private enum EmotionFamily {
        case sadness
        case anxiety
        case anger
        case joy
        case peaceful
        case powerful
        case unknown
    }

    private func emotionFamily(for emotion: String) -> EmotionFamily {
        let e = emotion.lowercased()
        if e.contains("sad") || e.contains("lonely") || e.contains("hurt") || e.contains("depress") {
            return .sadness
        }
        if e.contains("anx") || e.contains("panic") || e.contains("worr") || e.contains("scared") || e.contains("overwhelm") {
            return .anxiety
        }
        if e.contains("ang") || e.contains("mad") || e.contains("frustrat") || e.contains("rage") {
            return .anger
        }
        if e.contains("joy") || e.contains("happy") || e.contains("grate") || e.contains("excited") {
            return .joy
        }
        if e.contains("peace") || e.contains("calm") || e.contains("content") {
            return .peaceful
        }
        if e.contains("power") || e.contains("confident") || e.contains("proud") {
            return .powerful
        }
        return .unknown
    }

    private enum IntensityWeight {
        case high
        case medium
        case low
    }

    private func contextIntensityWeight(_ intensity: Int) -> IntensityWeight {
        if intensity >= 7 { return .high }
        if intensity >= 4 { return .medium }
        return .low
    }

    private enum EffortLevel {
        case low
        case medium
        case high
    }

    private func effortLevel(for rec: Recommendation) -> EffortLevel {
        let text = "\(rec.title) \(rec.reason) \(rec.action) \(rec.tags.joined(separator: " "))".lowercased()
        if containsAny(text, keywords: ["breathe", "water", "ground", "two-minute", "5 minute", "short walk", "pause", "stretch"]) {
            return .low
        }
        if containsAny(text, keywords: ["gym", "outing", "event", "concert", "group", "social", "dinner"]) {
            return .high
        }
        if rec.type == .connection && containsAny(text, keywords: ["call", "message", "text"]) {
            return .high
        }
        return .medium
    }

    private func isLowEffort(_ rec: Recommendation) -> Bool {
        effortLevel(for: rec) == .low
    }

    private func isSocialPressure(_ rec: Recommendation) -> Bool {
        let text = "\(rec.title) \(rec.reason) \(rec.action)".lowercased()
        return containsAny(text, keywords: ["call", "text someone", "friend", "group", "social", "reach out"])
    }

    private func isGroundingRecommendation(_ rec: Recommendation) -> Bool {
        let text = "\(rec.title) \(rec.reason) \(rec.action) \(rec.tags.joined(separator: " "))".lowercased()
        return containsAny(text, keywords: ["breathe", "ground", "slow exhale", "box breathing", "feet on the floor", "safety", "calm"])
    }

    private func isHighDistressContext(_ context: EmotionContext) -> Bool {
        let emotion = context.emotion.lowercased()
        let text = "\(context.journalText) \(context.stressors.joined(separator: " "))".lowercased()
        let distressEmotion = emotion.contains("sad") || emotion.contains("panic") || emotion.contains("anx")
        let distressWords = containsAny(text, keywords: ["panic", "spiral", "breaking down", "can't cope", "cannot cope", "distress", "unsafe"])
        return (context.intensity >= 8 && distressEmotion) || distressWords
    }

    private func containsAny(_ rec: Recommendation, keywords: [String]) -> Bool {
        let text = "\(rec.title) \(rec.reason) \(rec.action) \(rec.tags.joined(separator: " "))".lowercased()
        return containsAny(text, keywords: keywords)
    }

    private func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}
