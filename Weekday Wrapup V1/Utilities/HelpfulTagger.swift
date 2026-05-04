import Foundation

struct HelpfulTagger {
    static let tagMap: [String: [String]] = [
        "walk": ["walking", "movement"],
        "run": ["exercise", "movement"],
        "gym": ["exercise"],
        "music": ["music", "coping"],
        "journal": ["journaling", "reflection"],
        "write": ["journaling"],
        "friend": ["social", "connection"],
        "talk": ["social"],
        "sleep": ["rest"],
        "nap": ["rest"],
        "meditate": ["mindfulness"],
        "breathe": ["mindfulness"],
        "therapy": ["therapy"],
        "nature": ["nature"],
        "outside": ["nature"],
        "break": ["rest"],
        "shower": ["reset"],
        "eat": ["self-care"]
    ]

    static func extractTags(from text: String) -> [String] {
        let lower = text.lowercased()
        var tags: Set<String> = []

        for (keyword, mappedTags) in tagMap {
            if lower.contains(keyword) {
                tags.formUnion(mappedTags)
            }
        }

        return Array(tags).sorted()
    }
}
