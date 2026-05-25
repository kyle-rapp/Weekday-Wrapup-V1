import Foundation

/// FILE: Managers/AdaptiveLearningEngine.swift
/// Structured behavioral adaptation (non-ML): learns what stabilizes emotions safely.
actor AdaptiveLearningEngine {
    private let firestore: FirestoreManager

    init(firestore: FirestoreManager) {
        self.firestore = firestore
    }

    func processEvent(_ event: EmotionalEvent) async {
        var profile = await firestore.fetchAdaptiveProfile(userId: event.userId)

        let itemKey = (event.itemId ?? "unknown").lowercased()
        let category = event.metadata["category"]?.lowercased() ?? "unknown"
        let contextKey = contextKeyForEvent(event)
        let improvement = emotionalImprovementScore(event)
        let consistency = consistencyScore(profile: profile, itemId: itemKey)
        let voluntaryReuse = voluntaryReuseScore(event)
        let postActionStability = postActionStabilityScore(event)
        let helpfulnessScore = clamp(
            improvement + consistency + voluntaryReuse + postActionStability,
            min: -1.0,
            max: 1.0
        )

        switch event.eventType {
        case .recommendationInteraction, .dopamineMenuUsed, .postInteraction, .habitSignal:
            applyActivityLearning(
                profile: &profile,
                itemId: itemKey,
                category: category,
                contextKey: contextKey,
                helpfulnessScore: helpfulnessScore,
                event: event
            )
        case .dopamineMenuAdded:
            profile.categoryAffinities[category, default: 0] += 0.04
        case .dopamineMenuRemoved:
            profile.categoryAffinities[category, default: 0] -= 0.06
            profile.helpfulActivityScores[itemKey, default: 0] -= 0.05
        case .emotionCheckIn:
            profile.stabilizationScore = clamp(
                profile.stabilizationScore + (improvement * 0.08),
                min: -1,
                max: 1
            )
            profile.emotionalContextScores[contextKey, default: 0] += helpfulnessScore * 0.03
        }

        applySafetyRules(profile: &profile, event: event, itemId: itemKey, category: category)
        profile = normalized(profile)

        do {
            try await firestore.saveAdaptiveProfile(userId: event.userId, profile: profile)
        } catch {
            AppLogger.error("AdaptiveLearningEngine save failed: \(error.localizedDescription)")
        }
    }

    private func applyActivityLearning(
        profile: inout UserAdaptiveProfile,
        itemId: String,
        category: String,
        contextKey: String,
        helpfulnessScore: Double,
        event: EmotionalEvent
    ) {
        guard itemId != "unknown" else { return }

        // Positive reinforcement prioritizes emotional improvement over clicks.
        if helpfulnessScore > 0 {
            profile.helpfulActivityScores[itemId, default: 0] += 0.18 * helpfulnessScore
            profile.categoryAffinities[category, default: 0] += 0.10 * helpfulnessScore
            profile.emotionalContextScores[contextKey, default: 0] += 0.08 * helpfulnessScore
            profile.recentSuccessfulActions.insert(itemId, at: 0)
            profile.recentSuccessfulActions = Array(profile.recentSuccessfulActions.prefix(20))
            profile.stabilizationScore = clamp(profile.stabilizationScore + 0.05 * helpfulnessScore, min: -1, max: 1)
        } else {
            let penalty = abs(helpfulnessScore)
            profile.helpfulActivityScores[itemId, default: 0] -= 0.12 * penalty
            profile.unhealthyPatternScores[itemId, default: 0] += 0.14 * penalty
            profile.categoryAffinities[category, default: 0] -= 0.08 * penalty
            profile.emotionalContextScores[contextKey, default: 0] -= 0.05 * penalty
            profile.stabilizationScore = clamp(profile.stabilizationScore - 0.04 * penalty, min: -1, max: 1)
        }

        // Explicit didHelp signal is stronger than passive interaction.
        if let didHelp = event.didHelp {
            profile.helpfulActivityScores[itemId, default: 0] += didHelp ? 0.12 : -0.12
            if !didHelp {
                profile.unhealthyPatternScores[itemId, default: 0] += 0.10
            }
        }
    }

    private func applySafetyRules(
        profile: inout UserAdaptiveProfile,
        event: EmotionalEvent,
        itemId: String,
        category: String
    ) {
        let lowerTitle = (event.itemTitle ?? "").lowercased()
        let isDoomScrollItem = isDoomScrollingRelated(itemId: itemId, title: lowerTitle, tags: event.tags)

        // 1) Dessert saturation detection
        if category.contains("dessert") {
            profile.unhealthyPatternScores["dessert_saturation", default: 0] += 0.08
            profile.categoryAffinities["dessert", default: 0] -= 0.04
            profile.categoryAffinities["appetizer", default: 0] += 0.03
            profile.categoryAffinities["entree", default: 0] += 0.03
        }

        // 2) Doom scrolling + worsening mood lowers ranking strongly.
        if isDoomScrollItem {
            profile.unhealthyPatternScores[itemId, default: 0] += 0.12
            profile.unhealthyPatternScores["doom_scrolling_pattern", default: 0] += 0.10
            if (event.intensityChange ?? 0) > 0 {
                profile.unhealthyPatternScores[itemId, default: 0] += 0.10
                profile.helpfulActivityScores[itemId, default: 0] -= 0.12
            }
        }

        // 3) Emotional volatility protection.
        let beforeIntensity = event.emotionBefore?.intensity ?? 0
        let highRiskEmotion = (event.emotionBefore?.emotion.lowercased() ?? "").contains("sad")
            || (event.emotionBefore?.emotion.lowercased() ?? "").contains("anx")
            || (event.emotionBefore?.emotion.lowercased() ?? "").contains("panic")
        if beforeIntensity >= 8 && highRiskEmotion {
            profile.unhealthyPatternScores["volatility_risk", default: 0] += 0.12
            profile.categoryAffinities["appetizer", default: 0] += 0.06
            profile.categoryAffinities["side", default: 0] += 0.04
            profile.categoryAffinities["dessert", default: 0] -= 0.06
        }
    }

    private func emotionalImprovementScore(_ event: EmotionalEvent) -> Double {
        if let didHelp = event.didHelp {
            return didHelp ? 0.35 : -0.30
        }
        guard let delta = event.intensityChange else { return 0.0 }
        // Intensity dropping after action is good.
        if delta < 0 {
            return min(0.45, abs(delta) / 10.0 + 0.10)
        }
        if delta > 0 {
            return -min(0.45, delta / 10.0 + 0.08)
        }
        return 0.05
    }

    private func consistencyScore(profile: UserAdaptiveProfile, itemId: String) -> Double {
        let base = profile.helpfulActivityScores[itemId, default: 0]
        return clamp(base * 0.15, min: -0.20, max: 0.20)
    }

    private func voluntaryReuseScore(_ event: EmotionalEvent) -> Double {
        switch event.actionType {
        case .complete, .save, .add:
            return 0.12
        case .click, .reflect:
            return 0.04
        case .dismiss, .remove:
            return -0.10
        }
    }

    private func postActionStabilityScore(_ event: EmotionalEvent) -> Double {
        guard let after = event.emotionAfter else { return 0.0 }
        if after.intensity <= 3 { return 0.20 }
        if after.intensity <= 5 { return 0.10 }
        if after.intensity >= 8 { return -0.15 }
        return 0.03
    }

    private func contextKeyForEvent(_ event: EmotionalEvent) -> String {
        let emotion = event.emotionBefore?.emotion.lowercased() ?? "unknown"
        let intensityBand: String = {
            let value = event.emotionBefore?.intensity ?? 5
            if value >= 7 { return "high" }
            if value >= 4 { return "medium" }
            return "low"
        }()
        let hour = Calendar.current.component(.hour, from: event.timestamp)
        let timeBucket: String
        switch hour {
        case 5..<12: timeBucket = "morning"
        case 12..<17: timeBucket = "afternoon"
        case 17..<22: timeBucket = "evening"
        default: timeBucket = "night"
        }
        return "\(emotion)|\(intensityBand)|\(timeBucket)|\(event.source.rawValue)"
    }

    private func isDoomScrollingRelated(itemId: String, title: String, tags: [String]) -> Bool {
        let blob = ([itemId, title] + tags).joined(separator: " ").lowercased()
        let markers = [
            "doom", "scroll", "tiktok", "instagram", "x", "twitter", "facebook",
            "short-form", "youtube", "social media", "random internet", "news scrolling"
        ]
        return markers.contains { blob.contains($0) }
    }

    private func normalized(_ profile: UserAdaptiveProfile) -> UserAdaptiveProfile {
        var copy = profile
        copy.helpfulActivityScores = normalizeMap(copy.helpfulActivityScores)
        copy.unhealthyPatternScores = normalizeMap(copy.unhealthyPatternScores)
        copy.categoryAffinities = normalizeMap(copy.categoryAffinities)
        copy.emotionalContextScores = normalizeMap(copy.emotionalContextScores)
        copy.stabilizationScore = clamp(copy.stabilizationScore, min: -1, max: 1)
        copy.recentSuccessfulActions = Array(copy.recentSuccessfulActions.prefix(20))
        return copy
    }

    private func normalizeMap(_ values: [String: Double]) -> [String: Double] {
        values.reduce(into: [String: Double]()) { result, pair in
            result[pair.key] = clamp(pair.value, min: -1.5, max: 1.5)
        }
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }
}
