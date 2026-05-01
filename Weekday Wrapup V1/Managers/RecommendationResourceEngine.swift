import Foundation

/// FILE: Managers/RecommendationResourceEngine.swift
/// Keyword + emotion + stressor scoring → top printable resources.

struct ResourceRecommendation: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let url: String
    let tags: [String]
    /// Short line for cards.
    let summary: String

    init(title: String, url: String, tags: [String], summary: String) {
        self.id = url
        self.title = title
        self.url = url
        self.tags = tags
        self.summary = summary
    }
}

@MainActor
final class ResourceRecommendationManager: ObservableObject {
    static let shared = ResourceRecommendationManager()

    private var cache: [String: [ResourceRecommendation]] = [:]

    func recommendations(
        postId: String,
        postText: String,
        emotionTags: [String],
        stressors: [String]
    ) -> [ResourceRecommendation] {
        if let hit = cache[postId] { return hit }
        let list = RecommendationResourceEngine.rank(
            postText: postText,
            emotionTags: emotionTags,
            stressors: stressors
        )
        cache[postId] = list
        return list
    }

    func invalidate(postId: String) {
        cache.removeValue(forKey: postId)
    }
}

enum RecommendationResourceEngine {

    private static let catalog: [(title: String, url: String, tags: [String], summary: String)] = [
        ("Couples Communication Workbook", "https://www.southdenvertherapy.com/free-resources/p/free-couples-communication-workbook", ["relationship", "fight", "partner", "couple", "communication", "marriage"], "Structured prompts for clearer, kinder conversations."),
        ("Depression Workbook", "https://www.southdenvertherapy.com/free-resources/p/free-depression-workbook", ["sad", "depressed", "depression", "hopeless", "empty", "low mood"], "Gentle exercises when energy and motivation feel low."),
        ("Complete Anxiety Relief Journal", "https://www.southdenvertherapy.com/free-resources/p/complete-anxiety-relief-journal", ["anxiety", "anxious", "panic", "overthinking", "worry", "nervous"], "Journal prompts to slow racing thoughts."),
        ("Anger Management Workbook", "https://www.southdenvertherapy.com/free-resources/p/anger-management-workbook-for-men", ["angry", "anger", "rage", "mad", "irritated"], "Skills for cooling down before reacting."),
        ("Free CBT Therapy Journal", "https://www.southdenvertherapy.com/free-resources/p/free-cbt-therapy-journal", ["cbt", "thoughts", "patterns", "reframe", "cognitive"], "Catch unhelpful thought loops and test kinder alternatives."),
        ("Grief & Loss Workbook", "https://www.southdenvertherapy.com/free-resources/p/grief-loss-workbook", ["grief", "loss", "death", "mourning"], "Supportive structure when loss feels heavy."),
        ("Healthy Boundaries Toolkit", "https://www.southdenvertherapy.com/free-resources/p/healthy-boundaries-toolkit-printable", ["boundaries", "limits", "overwhelmed", "say no"], "Clarify limits without guilt-tripping yourself."),
        ("Conflict Resolution Worksheet", "https://www.southdenvertherapy.com/free-resources/p/free-conflict-resolution-worksheet-for-couples", ["conflict", "resolution", "disagreement", "argument"], "A simple path from heat to repair."),
        ("Rebuilding Trust After Betrayal", "https://www.southdenvertherapy.com/free-resources/p/rebuilding-trust-after-betrayal-couples-recovery-workbook", ["trust", "betrayal", "affair", "cheating"], "Slow, honest steps when trust has cracked."),
        ("Premarital Preparation Workbook", "https://www.southdenvertherapy.com/free-resources/p/before-we-say-i-do-premarital-preparation-workbook", ["premarital", "engaged", "wedding", "marriage prep"], "Big conversations before big commitments.")
    ]

    static func rank(postText: String, emotionTags: [String], stressors: [String]) -> [ResourceRecommendation] {
        let blob = ([postText] + emotionTags + stressors)
            .joined(separator: " ")
            .lowercased()

        func keywordScore(tags: [String]) -> Int {
            var s = 0
            for t in tags {
                if blob.contains(t) { s += t.count >= 8 ? 4 : 2 }
            }
            return s
        }

        func emotionScore(tags: [String]) -> Int {
            let em = emotionTags.joined(separator: " ").lowercased()
            var s = 0
            for t in tags {
                if em.contains(t) { s += 3 }
            }
            return s
        }

        func stressorScore(tags: [String]) -> Int {
            let st = stressors.joined(separator: " ").lowercased()
            var s = 0
            for t in tags {
                if st.contains(t) { s += 3 }
            }
            return s
        }

        let scored = catalog.map { row -> (Int, ResourceRecommendation) in
            let kw = keywordScore(tags: row.tags)
            let em = emotionScore(tags: row.tags)
            let st = stressorScore(tags: row.tags)
            let score = kw + em + st
            let rec = ResourceRecommendation(title: row.title, url: row.url, tags: row.tags, summary: row.summary)
            return (score, rec)
        }
        .filter { $0.0 > 0 }
        .sorted { $0.0 > $1.0 }

        let out = Array(scored.prefix(3).map(\.1))
        if out.isEmpty { return [] }
        return Array(out.prefix(3))
    }

    /// Single best match for daily check-in; never empty.
    static func bestResource(postText: String, emotionTags: [String], stressors: [String]) -> ResourceRecommendation {
        let ranked = rank(postText: postText, emotionTags: emotionTags, stressors: stressors)
        if let first = ranked.first { return first }
        return ResourceRecommendation(
            title: "Free CBT Therapy Journal",
            url: "https://www.southdenvertherapy.com/free-resources/p/free-cbt-therapy-journal",
            tags: ["cbt", "default"],
            summary: "A gentle printable when keywords don’t match a specific workbook yet."
        )
    }
}
