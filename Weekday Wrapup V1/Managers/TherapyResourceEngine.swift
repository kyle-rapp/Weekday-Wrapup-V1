import Foundation

/// FILE: Managers/TherapyResourceEngine.swift
/// Keyword -> resource matcher (max 5, no network calls).

enum TherapyResourceEngine {
    static let resources: [Resource] = [
        Resource(title: "Complete Anxiety Relief Journal", url: "https://www.southdenvertherapy.com/free-resources/p/complete-anxiety-relief-journal", tags: ["anxiety"]),
        Resource(title: "Anxiety Quiz", url: "https://www.southdenvertherapy.com/anxiety-quiz", tags: ["anxiety"]),
        Resource(title: "Depression Screening Quiz", url: "https://www.southdenvertherapy.com/depression-screening-quiz", tags: ["depression"]),
        Resource(title: "Burnout Quiz", url: "https://www.southdenvertherapy.com/burnout-quiz", tags: ["overwhelmed"]),
        Resource(title: "PTSD Quiz", url: "https://www.southdenvertherapy.com/ptsd-quiz", tags: ["trauma"]),
        Resource(title: "Letting Go of Perfectionism Workbook", url: "https://www.southdenvertherapy.com/free-resources/p/letting-go-of-perfectionism-workbook", tags: ["perfectionism"]),
        Resource(title: "Fawn Response Quiz", url: "https://www.southdenvertherapy.com/fawn-response-quiz", tags: ["people pleasing"]),
        Resource(title: "Couples Journal Worksheets", url: "https://www.southdenvertherapy.com/free-resources/p/couples-journal-worksheets-improve-relationship", tags: ["relationships"]),
        Resource(title: "Fair Fighting Rules for Couples", url: "https://www.southdenvertherapy.com/free-resources/p/fair-fighting-rules-for-couples", tags: ["relationships", "conflict"]),
        Resource(title: "Couples Connection Toolkit", url: "https://www.southdenvertherapy.com/free-resources/p/couples-connection-toolkit", tags: ["relationships"]),
        Resource(title: "Conflict Resolution Worksheet", url: "https://www.southdenvertherapy.com/free-resources/p/free-conflict-resolution-worksheet-for-couples", tags: ["relationships", "conflict"]),
        Resource(title: "Love Language Quiz", url: "https://www.southdenvertherapy.com/love-language-quiz", tags: ["relationships"]),
        Resource(title: "Attachment Style Quiz", url: "https://www.southdenvertherapy.com/attachment-style-quiz", tags: ["relationships", "identity"]),
        Resource(title: "Enneagram Test", url: "https://www.southdenvertherapy.com/enneagram-test", tags: ["identity"]),
        Resource(title: "CBT Thought Record", url: "https://www.southdenvertherapy.com/free-resources/p/cbt-thought-record", tags: ["identity", "self care"]),
        Resource(title: "EMDR Resource Guide", url: "https://www.southdenvertherapy.com/free-resources/p/emdr-resource-guide", tags: ["identity", "trauma"]),
        Resource(title: "Healthy Boundaries Toolkit", url: "https://www.southdenvertherapy.com/free-resources/p/healthy-boundaries-toolkit-printable", tags: ["boundaries"]),
        Resource(title: "Feelings Communication Scripts", url: "https://www.southdenvertherapy.com/free-resources/p/feelings-communication-scripts", tags: ["communication"]),
        Resource(title: "Communication Style Quiz", url: "https://www.southdenvertherapy.com/communication-style-quiz", tags: ["communication"]),
        Resource(title: "Conflict Style Quiz", url: "https://www.southdenvertherapy.com/conflict-style-quiz", tags: ["conflict"]),
        Resource(title: "Codependency Quiz", url: "https://www.southdenvertherapy.com/codependency-quiz", tags: ["codependency"]),
        Resource(title: "Request Therapy", url: "https://southdenvertherapy.sessionshealth.com/request", tags: ["therapy"]),
        Resource(title: "Pursuer Withdrawer Quiz", url: "https://www.southdenvertherapy.com/pursuer-withdrawer-quiz", tags: ["loneliness", "relationships"]),
        Resource(title: "Feelings List Printable", url: "https://www.southdenvertherapy.com/free-resources/p/feelings-list-printable", tags: ["self care"]),
        Resource(title: "Free CBT Therapy Journal", url: "https://www.southdenvertherapy.com/free-resources/p/free-cbt-therapy-journal", tags: ["self care"]),
        Resource(title: "Self-Love Workbook for Women", url: "https://www.southdenvertherapy.com/free-resources/p/self-love-workbook-for-women", tags: ["self care"]),
        Resource(title: "Adult Mental Health Toolkit", url: "https://www.southdenvertherapy.com/free-resources/p/adult-mental-health-toolkit", tags: ["self care"]),
        Resource(title: "Premarital Preparation Workbook", url: "https://www.southdenvertherapy.com/free-resources/p/before-we-say-i-do-premarital-preparation-workbook", tags: ["commitment", "relationships"]),
        Resource(title: "Couples Intimacy Exercise Guide", url: "https://www.southdenvertherapy.com/free-resources/p/couples-intimacy-bonding-exercise-guide-pdf", tags: ["intimacy", "relationships"]),
        Resource(title: "Grief & Loss Workbook", url: "https://www.southdenvertherapy.com/free-resources/p/grief-loss-workbook", tags: ["grief"])
    ]

    private static let normalization: [String: String] = [
        "spiraling": "anxiety",
        "drained": "overwhelmed",
        "checked out": "depression",
        "clingy": "codependency",
        "walked all over": "boundaries"
    ]

    static func matchResources(text: String, emotions: [String]) -> [TherapyResource] {
        let normalizedText = normalize(text.lowercased())
        let normalizedEmotions = emotions.map { normalize($0.lowercased()) }
        if normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && normalizedEmotions.isEmpty {
            return []
        }

        let scored = resources.compactMap { resource -> (Double, TherapyResource)? in
            var score = 0.0

            for tag in resource.tags {
                let t = normalize(tag.lowercased())
                if !normalizedText.isEmpty, normalizedText.contains(t) { score += 3 }
                if normalizedEmotions.contains(where: { $0.contains(t) || t.contains($0) }) { score += 2 }
            }

            guard score > 0 else { return nil }
            return (score, TherapyResource(title: resource.title, url: resource.url, tags: resource.tags))
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

    private static func normalize(_ raw: String) -> String {
        var out = raw
        for (from, to) in normalization {
            out = out.replacingOccurrences(of: from, with: to)
        }
        return out
    }
}

