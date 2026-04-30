import Foundation

/// FILE: Models/ResourceLink.swift
/// Curated printable workbooks / journals (v1 keyword router).

struct ResourceLink: Identifiable, Equatable, Hashable {
    var id: String { url }
    let title: String
    let url: String
    let keywords: [String]
}

enum CuratedResourceLibrary {
    static let all: [ResourceLink] = [
        ResourceLink(
            title: "Couples Communication Workbook",
            url: "https://www.southdenvertherapy.com/free-resources/p/free-couples-communication-workbook",
            keywords: ["relationship", "fight", "partner", "couple", "communication", "marriage"]
        ),
        ResourceLink(
            title: "Depression Workbook",
            url: "https://www.southdenvertherapy.com/free-resources/p/free-depression-workbook",
            keywords: ["sad", "depressed", "depression", "hopeless", "low mood"]
        ),
        ResourceLink(
            title: "Complete Anxiety Relief Journal",
            url: "https://www.southdenvertherapy.com/free-resources/p/complete-anxiety-relief-journal",
            keywords: ["anxiety", "anxious", "overthinking", "worry", "panic", "nervous"]
        ),
        ResourceLink(
            title: "Anger Management Workbook (for men)",
            url: "https://www.southdenvertherapy.com/free-resources/p/anger-management-workbook-for-men",
            keywords: ["angry", "anger", "rage", "mad", "irritated"]
        ),
        ResourceLink(
            title: "Grief & Loss Workbook",
            url: "https://www.southdenvertherapy.com/free-resources/p/grief-loss-workbook",
            keywords: ["grief", "loss", "death", "mourning", "bereavement"]
        ),
        ResourceLink(
            title: "Free CBT Therapy Journal",
            url: "https://www.southdenvertherapy.com/free-resources/p/free-cbt-therapy-journal",
            keywords: ["cbt", "thoughts", "patterns", "reframe", "cognitive"]
        ),
        ResourceLink(
            title: "Relationship Repair Toolkit",
            url: "https://www.southdenvertherapy.com/free-resources/p/relationship-repair-toolkit-after-a-fight",
            keywords: ["repair", "after a fight", "apology", "argument", "conflict"]
        ),
        ResourceLink(
            title: "Rebuilding Trust After Betrayal",
            url: "https://www.southdenvertherapy.com/free-resources/p/rebuilding-trust-after-betrayal-couples-recovery-workbook",
            keywords: ["trust", "betrayal", "affair", "cheating", "infidelity"]
        ),
        ResourceLink(
            title: "Conflict Resolution Worksheet (Couples)",
            url: "https://www.southdenvertherapy.com/free-resources/p/free-conflict-resolution-worksheet-for-couples",
            keywords: ["conflict", "resolution", "disagreement", "couples"]
        ),
        ResourceLink(
            title: "Healthy Boundaries Toolkit",
            url: "https://www.southdenvertherapy.com/free-resources/p/healthy-boundaries-toolkit-printable",
            keywords: ["boundaries", "limits", "say no", "overwhelmed"]
        ),
        ResourceLink(
            title: "Shadow Work & Inner Child Healing",
            url: "https://www.southdenvertherapy.com/free-resources/p/shadow-work-inner-child-healing-workbook",
            keywords: ["inner child", "shadow", "healing", "childhood", "wounds"]
        ),
        ResourceLink(
            title: "Couples Financial Harmony Workbook",
            url: "https://www.southdenvertherapy.com/free-resources/p/couples-financial-harmony-workbook-money-marriage",
            keywords: ["money", "finances", "budget", "spending", "financial"]
        ),
        ResourceLink(
            title: "Premarital Preparation Workbook",
            url: "https://www.southdenvertherapy.com/free-resources/p/before-we-say-i-do-premarital-preparation-workbook",
            keywords: ["premarital", "engaged", "wedding", "marriage prep"]
        ),
        ResourceLink(
            title: "Feelings Communication Scripts",
            url: "https://www.southdenvertherapy.com/free-resources/p/feelings-communication-scripts",
            keywords: ["feelings", "scripts", "hard conversation", "communicate"]
        ),
        ResourceLink(
            title: "Letting Go of Perfectionism",
            url: "https://www.southdenvertherapy.com/free-resources/p/letting-go-of-perfectionism-workbook",
            keywords: ["perfectionism", "perfect", "standards", "pressure"]
        ),
        ResourceLink(
            title: "Kids Emotional Wellness Toolkit",
            url: "https://www.southdenvertherapy.com/free-resources/p/kids-emotional-wellness-toolkit",
            keywords: ["kids", "child", "parent", "family", "school age"]
        )
    ]

    /// Scans insight, goal, and whoop text; returns 1–2 best-matching links.
    static func suggestions(insight: String, goal: String, whoop: String, emotions: [String]) -> [ResourceLink] {
        let blob = ([insight, goal, whoop] + emotions)
            .joined(separator: " ")
            .lowercased()

        guard !blob.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        func score(for link: ResourceLink) -> Int {
            var s = 0
            for kw in link.keywords {
                if blob.contains(kw) { s += kw.count >= 8 ? 3 : 2 }
            }
            return s
        }

        let ranked = all
            .map { (link: $0, score: score(for: $0)) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }

        var out: [ResourceLink] = []
        for item in ranked.prefix(2) {
            if !out.contains(where: { $0.url == item.link.url }) {
                out.append(item.link)
            }
        }
        return out
    }
}
