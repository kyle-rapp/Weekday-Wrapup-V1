import Foundation

/// FILE: Managers/PersonalizedRecommendationEngine.swift
/// v2 weighted scoring: emotion / tags / preferences / helpful-tag history + intensity + weather.
/// Returns 2–3 items, ranked.

final class PersonalizedRecommendationEngine {

    private struct Candidate {
        var score: Int
        let rec: Recommendation
    }

    /// `score = emotionMatch*3 + tagMatch*5 + preferenceMatch*4 + historyMatch*6` per candidate (weights are small integers 0–3).
    func generate(
        emotion: String,
        intensity: Int,
        tags: [String],
        preferences: UserPreferences?,
        history: [CheckInData],
        weather: RecommendationWeatherHint = .neutral
    ) -> [Recommendation] {
        let e = emotion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let level = max(1, min(10, intensity))
        let tagCounts = Self.helpfulTagCountsForSimilarMood(history: history, emotionHint: e)
        let mergedTags = Self.mergeTagSignals(explicit: tags, fromHistory: tagCounts)

        var pool: [Candidate] = []

        func add(
            _ title: String,
            _ reason: String,
            _ action: String,
            _ type: RecommendationType,
            emotionMatch: Int,
            tagMatch: Int,
            preferenceMatch: Int,
            historyMatch: Int
        ) {
            let em = min(3, max(0, emotionMatch))
            let tm = min(3, max(0, tagMatch))
            let pm = min(3, max(0, preferenceMatch))
            let hm = min(3, max(0, historyMatch))
            let score = em * 3 + tm * 5 + pm * 4 + hm * 6
            pool.append(Candidate(score: score, rec: Recommendation(title: title, reason: reason, action: action, type: type)))
        }

        func emotionTier(for keywords: [String]) -> Int {
            keywords.contains { e.contains($0) } ? 2 : 0
        }

        // --- Weather ---
        if weather == .sunny, preferences?.enjoysWalking == true, level <= 7 {
            add(
                "Take a 10-minute walk outside",
                "It’s nice out—and moving helps many people land back in their bodies.",
                "Start",
                .action,
                emotionMatch: 0,
                tagMatch: 0,
                preferenceMatch: 2,
                historyMatch: 0
            )
        }
        if weather == .rainy, level <= 7 {
            add(
                "Cozy reset indoors",
                "Rainy days pair well with a slower pace—small comforts can still shift your state.",
                "Try it",
                .regulation,
                emotionMatch: 0,
                tagMatch: 0,
                preferenceMatch: 1,
                historyMatch: 0
            )
        }

        // --- History: helpful tags for similar moods ---
        if let top = mergedTags.max(by: { $0.value < $1.value }), top.value >= 2 {
            let label = top.key
            let reason = "When you’ve felt similar before, \(label.lowercased()) showed up in what helped—worth another try."
            add(
                "Repeat what worked: \(label)",
                reason,
                "Start",
                .action,
                emotionMatch: 1,
                tagMatch: min(3, top.value / 2),
                preferenceMatch: 0,
                historyMatch: min(3, top.value)
            )
        }

        // --- Preferences ---
        if preferences?.journals == true, level <= 8 {
            add(
                "Three-line journal",
                "You’ve shared that writing helps—keep it tiny so it feels doable.",
                "Open notes",
                .reflection,
                emotionMatch: 0,
                tagMatch: 0,
                preferenceMatch: 2,
                historyMatch: 0
            )
        }
        if preferences?.meditates == true, level >= 5 {
            add(
                "Two-minute grounding breath",
                "You’ve indicated meditation fits you—short beats perfect when intensity is up.",
                "Breathe",
                .regulation,
                emotionMatch: 1,
                tagMatch: 0,
                preferenceMatch: 2,
                historyMatch: 0
            )
        }
        if preferences?.callsFriends == true, level <= 8 {
            add(
                "Send one honest text",
                "Connection is in your toolkit—one message can soften the day without pressure.",
                "Reach out",
                .connection,
                emotionMatch: 1,
                tagMatch: 0,
                preferenceMatch: 2,
                historyMatch: 0
            )
        }
        if preferences?.hasPet == true, level <= 8 {
            add(
                "Walk your pet",
                "Movement plus companionship can be a steady reset when emotions run high.",
                "Go",
                .action,
                emotionMatch: 0,
                tagMatch: 0,
                preferenceMatch: 2,
                historyMatch: 0
            )
        }
        if preferences?.enjoysWalking == true, weather != .rainy, level <= 7 {
            add(
                "Easy walk, no destination",
                "Walking is something you’ve marked as helpful—keep the bar low.",
                "Step out",
                .action,
                emotionMatch: 0,
                tagMatch: 0,
                preferenceMatch: 2,
                historyMatch: 0
            )
        }

        // --- Emotion bases ---
        if e.contains("angry") || e.contains("mad") || e.contains("frustrated") {
            let tier = emotionTier(for: ["angry", "mad", "frustrated"])
            if level <= 4 {
                add("Change rooms for two minutes", "Small spatial shifts can interrupt the heat of frustration.", "Move", .regulation, emotionMatch: tier, tagMatch: 0, preferenceMatch: 0, historyMatch: 0)
            } else if level <= 7 {
                add("Push pause before you respond", "Anger often wants speed—space protects what you care about.", "Wait", .reflection, emotionMatch: tier, tagMatch: 0, preferenceMatch: 0, historyMatch: 0)
            } else {
                add("Box breathing, four counts", "At high intensity, simple breath pacing is a reliable regulator.", "Breathe", .regulation, emotionMatch: tier, tagMatch: 0, preferenceMatch: 0, historyMatch: 0)
            }
        } else if e.contains("sad") || e.contains("hurt") || e.contains("lonely") {
            let tier = emotionTier(for: ["sad", "hurt", "lonely"])
            if level <= 4 {
                add("Warm drink + one window of light", "Low intensity sadness often softens with tiny sensory care.", "Rest", .regulation, emotionMatch: tier, tagMatch: 0, preferenceMatch: 0, historyMatch: 0)
            } else if level <= 7 {
                add("Name one person who gets you", "Connection doesn’t have to be a big conversation—just a thread.", "Think", .connection, emotionMatch: tier, tagMatch: 0, preferenceMatch: 0, historyMatch: 0)
            } else {
                add("Ground with 5-4-3-2-1", "When sadness feels heavy, sensory grounding can steady the body.", "Ground", .regulation, emotionMatch: tier, tagMatch: 0, preferenceMatch: 0, historyMatch: 0)
            }
        } else if e.contains("anxious") || e.contains("worried") || e.contains("nervous") || e.contains("scared") {
            let tier = emotionTier(for: ["anxious", "worried", "nervous", "scared"])
            if level <= 4 {
                add("Label the worry in one sentence", "Naming tightens the loop—keep it short and kind.", "Write", .reflection, emotionMatch: tier, tagMatch: 0, preferenceMatch: 0, historyMatch: 0)
            } else if level <= 7 {
                add("Slow exhale, twice as long as inhale", "Longer exhales nudge your nervous system toward calm.", "Breathe", .regulation, emotionMatch: tier, tagMatch: 0, preferenceMatch: 0, historyMatch: 0)
            } else {
                add("Feet on the floor, press gently", "High anxiety benefits from concrete body anchors.", "Ground", .regulation, emotionMatch: tier, tagMatch: 0, preferenceMatch: 0, historyMatch: 0)
            }
        } else if e.contains("peace") || e.contains("calm") || e.contains("content") || e.contains("happy") || e.contains("joy") {
            add(
                "Lock in one micro-habit",
                "You’re in a steadier window—notice what you did today that you can repeat tomorrow.",
                "Note it",
                .reflection,
                emotionMatch: 2,
                tagMatch: 0,
                preferenceMatch: 0,
                historyMatch: 0
            )
        }

        // --- Safe defaults ---
        add("Box breathing, one round", "Breathing stays available even when you don’t have data yet.", "Breathe", .regulation, emotionMatch: 0, tagMatch: 0, preferenceMatch: 0, historyMatch: 0)
        add("One-page brain dump", "Journaling is a gentle default that still respects your pace.", "Write", .reflection, emotionMatch: 0, tagMatch: 0, preferenceMatch: 0, historyMatch: 0)
        if weather != .rainy {
            add("Five-minute walk", "A short walk is one of the most repeatable resets.", "Walk", .action, emotionMatch: 0, tagMatch: 0, preferenceMatch: 0, historyMatch: 0)
        }

        let gated = pool.filter { cand in
            guard level >= 8 else { return true }
            if cand.rec.type == .action, cand.rec.title.lowercased().contains("walk") {
                return cand.score >= 18 || weather == .sunny || preferences?.enjoysWalking == true
            }
            return true
        }

        var bestByTitle: [String: Candidate] = [:]
        for c in gated {
            let key = c.rec.title.lowercased()
            if let existing = bestByTitle[key] {
                if c.score > existing.score { bestByTitle[key] = c }
            } else {
                bestByTitle[key] = c
            }
        }

        let sorted = bestByTitle.values.sorted { $0.score > $1.score }
        var out: [Recommendation] = sorted.prefix(3).map(\.rec)
        if out.count == 1, sorted.count >= 2 {
            out = [sorted[0].rec, sorted[1].rec]
        }
        if out.isEmpty {
            return [
                Recommendation(
                    title: "Check in again soon",
                    reason: "The more you log what helps, the sharper these suggestions become.",
                    action: "Open Share",
                    type: .reflection
                )
            ]
        }
        return Array(out.prefix(3))
    }

    private static func mergeTagSignals(explicit: [String], fromHistory: [String: Int]) -> [String: Int] {
        var out = fromHistory
        for t in explicit {
            let k = t.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !k.isEmpty else { continue }
            out[k, default: 0] += 2
        }
        return out
    }

    private static func helpfulTagCountsForSimilarMood(history: [CheckInData], emotionHint: String) -> [String: Int] {
        let hint = emotionHint.lowercased()
        let keywords: [String] = {
            if hint.contains("sad") || hint.contains("hurt") { return ["sad", "hurt", "lonely", "tired", "bored"] }
            if hint.contains("angry") || hint.contains("mad") { return ["angry", "mad", "frustrated", "hostile"] }
            if hint.contains("anxious") || hint.contains("worried") || hint.contains("nervous") || hint.contains("scared") {
                return ["anxious", "worried", "nervous", "scared"]
            }
            if hint.contains("happy") || hint.contains("joy") || hint.contains("peace") { return ["happy", "joy", "peace", "calm", "content"] }
            return []
        }()

        let sorted = history.sorted { $0.date < $1.date }
        let recent = Array(sorted.suffix(24))

        var counts: [String: Int] = [:]
        for entry in recent {
            let blob = entry.selectedEmotions.map { $0.lowercased() }.joined(separator: " ")
            let overlap: Bool = {
                if keywords.isEmpty { return true }
                return keywords.contains { blob.contains($0) }
            }()
            guard overlap else { continue }
            for t in entry.helpfulTags ?? [] {
                let key = t.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { continue }
                counts[key, default: 0] += 1
            }
        }
        return counts
    }
}

extension PersonalizedRecommendationEngine {
    static func moodContext(from history: [CheckInData]) -> (emotion: String, intensity: Int, tags: [String]) {
        guard !history.isEmpty else { return ("", 5, []) }
        let sorted = history.sorted { $0.date < $1.date }
        let recent = Array(sorted.suffix(10))
        guard let last = sorted.last else { return ("", 5, []) }
        let emotion = last.firstSelectedEmotionLabel
        let ints = recent.compactMap(\.intensity)
        let intensity: Int
        if ints.isEmpty {
            intensity = min(10, max(1, last.intensity ?? 5))
        } else {
            intensity = min(10, max(1, ints.reduce(0, +) / ints.count))
        }
        let tags = last.helpfulTags ?? []
        return (emotion, intensity, tags)
    }
}
