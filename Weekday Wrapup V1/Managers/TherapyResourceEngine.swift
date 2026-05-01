import Foundation

/// FILE: Managers/TherapyResourceEngine.swift
/// Keyword -> resource matcher (max 5, no network calls).

enum TherapyResourceEngine {
    static let resources: [TherapyResource] = [
        TherapyResource(title: "Complete Anxiety Relief Journal", url: "https://www.southdenvertherapy.com/free-resources/p/complete-anxiety-relief-journal", tags: ["anxiety", "calm", "overthinking", "cbt"]),
        TherapyResource(title: "Depression Workbook", url: "https://www.southdenvertherapy.com/free-resources/p/free-depression-workbook", tags: ["depression", "low mood", "self-worth"]),
        TherapyResource(title: "Anger Management Workbook for Men", url: "https://www.southdenvertherapy.com/free-resources/p/anger-management-workbook-for-men", tags: ["anger", "conflict", "regulation"]),
        TherapyResource(title: "Free Couples Communication Workbook", url: "https://www.southdenvertherapy.com/free-resources/p/free-couples-communication-workbook", tags: ["relationship", "communication", "conflict"]),
        TherapyResource(title: "Free Conflict Resolution Workbook for Couples", url: "https://www.southdenvertherapy.com/free-resources/p/free-conflict-resolution-worksheet-for-couples", tags: ["conflict", "relationship", "communication"]),
        TherapyResource(title: "Rebuilding Trust After Betrayal Workbook", url: "https://www.southdenvertherapy.com/free-resources/p/rebuilding-trust-after-betrayal-couples-recovery-workbook", tags: ["trust", "relationship", "repair"]),
        TherapyResource(title: "Grief & Loss Workbook", url: "https://www.southdenvertherapy.com/free-resources/p/grief-loss-workbook", tags: ["grief", "loss", "healing"]),
        TherapyResource(title: "Adult Mental Health Toolkit", url: "https://www.southdenvertherapy.com/free-resources/p/adult-mental-health-toolkit", tags: ["anxiety", "depression", "self-care", "cbt"]),
        TherapyResource(title: "Emotional Regulation Workbook for Adults", url: "https://www.southdenvertherapy.com/free-resources/p/emotional-regulation-workbook-adults-dbt-skills", tags: ["regulation", "dbt", "anxiety", "anger"]),
        TherapyResource(title: "Free CBT Therapy Journal", url: "https://www.southdenvertherapy.com/free-resources/p/free-cbt-therapy-journal", tags: ["cbt", "thoughts", "anxiety", "depression"]),
        TherapyResource(title: "GAD-7 Anxiety Assessment (Printable)", url: "https://www.southdenvertherapy.com/free-resources/p/gad-7-anxiety-assessment-printable", tags: ["anxiety", "assessment", "calm"]),
        TherapyResource(title: "CBT Thought Record Worksheet", url: "https://www.southdenvertherapy.com/free-resources/p/cbt-thought-record", tags: ["cbt", "overthinking", "anxiety", "self-worth"]),
        TherapyResource(title: "DBT Skills Overview Pack", url: "https://www.southdenvertherapy.com/free-resources/p/dbt-skills-overview-pack", tags: ["dbt", "regulation", "distress tolerance", "boundaries"]),
        TherapyResource(title: "Healthy Boundaries Toolkit", url: "https://www.southdenvertherapy.com/free-resources/p/healthy-boundaries-toolkit-printable", tags: ["boundaries", "self-worth", "communication"]),
        TherapyResource(title: "From People-Pleasing to Authentic Living", url: "https://www.southdenvertherapy.com/free-resources/p/people-pleasing-to-authentic-living-workbook", tags: ["boundaries", "self-worth", "assertiveness"]),
        TherapyResource(title: "Self-Love Workbook for Women", url: "https://www.southdenvertherapy.com/free-resources/p/self-love-workbook-for-women", tags: ["self-worth", "self-compassion", "healing"]),
        TherapyResource(title: "Reframing Your Inner Critic", url: "https://www.southdenvertherapy.com/free-resources/p/reframing-your-inner-critic-workbook", tags: ["self-worth", "cbt", "self-talk"]),
        TherapyResource(title: "30 Days of Self-Compassion", url: "https://www.southdenvertherapy.com/free-resources/p/30-days-of-self-compassion", tags: ["self-worth", "calm", "healing"]),
        TherapyResource(title: "Breaking the Overthinking Cycle", url: "https://www.southdenvertherapy.com/free-resources/p/breaking-the-overthinking-cycle", tags: ["overthinking", "anxiety", "cbt", "calm"]),
        TherapyResource(title: "The High-Functioning Depression Guide", url: "https://www.southdenvertherapy.com/free-resources/p/high-functioning-depression-guide-printable", tags: ["depression", "burnout", "self-worth"]),
        TherapyResource(title: "Personalized Recovery Plan (Burnout & Depression)", url: "https://www.southdenvertherapy.com/free-resources/p/personalized-recovery-plan-burnout-depression", tags: ["depression", "burnout", "recovery"]),
        TherapyResource(title: "Calming Relationship Anxiety", url: "https://www.southdenvertherapy.com/free-resources/p/calming-relationship-anxiety-workbook", tags: ["relationship", "anxiety", "trust", "calm"]),
        TherapyResource(title: "How to Express Your Feelings Scripts", url: "https://www.southdenvertherapy.com/free-resources/p/feelings-communication-scripts", tags: ["communication", "relationship", "conflict"]),
        TherapyResource(title: "Fair Fighting Rules for Couples", url: "https://www.southdenvertherapy.com/free-resources/p/fair-fighting-rules-for-couples", tags: ["conflict", "relationship", "communication"]),
        TherapyResource(title: "How to Stay Present During Difficult Conversations", url: "https://www.southdenvertherapy.com/free-resources/p/stay-present-during-difficult-conversations", tags: ["conflict", "communication", "regulation"]),
        TherapyResource(title: "Relationship Health Checklist", url: "https://www.southdenvertherapy.com/free-resources/p/relationship-health-checklist", tags: ["relationship", "trust", "communication"]),
        TherapyResource(title: "Couples Journal & Worksheets", url: "https://www.southdenvertherapy.com/free-resources/p/couples-journal-worksheets-improve-relationship", tags: ["relationship", "communication", "growth"]),
        TherapyResource(title: "Love Language Action Plan", url: "https://www.southdenvertherapy.com/free-resources/p/love-language-action-plan-printable", tags: ["relationship", "communication", "growth"]),
        TherapyResource(title: "Opening Up Safely (Emotional Intimacy Exercises)", url: "https://www.southdenvertherapy.com/free-resources/p/opening-up-safely-emotional-intimacy", tags: ["relationship", "trust", "communication"]),
        TherapyResource(title: "EMDR Resource Guide", url: "https://www.southdenvertherapy.com/free-resources/p/emdr-resource-guide", tags: ["trauma", "grief", "anxiety", "healing"]),
        TherapyResource(title: "Letting Go of Perfectionism Workbook", url: "https://www.southdenvertherapy.com/free-resources/p/letting-go-of-perfectionism-workbook", tags: ["self-worth", "anxiety", "cbt", "burnout"])
    ]

    static func matchResources(text: String, emotions: [String]) -> [TherapyResource] {
        let lowerText = text.lowercased()
        let lowerEmotions = emotions.map { $0.lowercased() }
        if lowerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && lowerEmotions.isEmpty {
            return []
        }

        let scored = resources.compactMap { resource -> (Double, TherapyResource)? in
            var score = 0.0

            for tag in resource.tags {
                let t = tag.lowercased()
                if !lowerText.isEmpty, lowerText.contains(t) { score += 3 }
                if lowerEmotions.contains(where: { $0.contains(t) || t.contains($0) }) { score += 2 }
            }

            guard score > 0 else { return nil }
            return (score, resource)
        }
        .sorted { lhs, rhs in
            if lhs.0 != rhs.0 { return lhs.0 > rhs.0 }
            return lhs.1.title < rhs.1.title
        }

        var seenUrls = Set<String>()
        var out: [TherapyResource] = []
        for (_, item) in scored where out.count < 5 {
            guard seenUrls.insert(item.url).inserted else { continue }
            out.append(item)
        }
        return out
    }
}

