import Foundation

/// FILE: Models/FeedReactions.swift
/// Full reaction palette for posts (Firestore `reactions` map keys).

struct ReactionPaletteSection: Identifiable {
    let id: String
    let title: String
    let emojis: [String]
}

enum FeedReactions {
    /// Grouped for the expanded picker (Support / Empathy / Energy / Humor).
    static let paletteSections: [ReactionPaletteSection] = [
        ReactionPaletteSection(id: "support", title: "Support", emojis: [
            "❤️", "🙏", "🤍", "🫶", "💙", "🫂"
        ]),
        ReactionPaletteSection(id: "empathy", title: "Empathy", emojis: [
            "😢", "😮", "🌊", "💭", "😰", "🧠"
        ]),
        ReactionPaletteSection(id: "energy", title: "Energy", emojis: [
            "🔥", "💥", "⚡️", "💪", "✨", "🌱", "🌿", "🧘", "😊", "🎉", "💛"
        ]),
        ReactionPaletteSection(id: "humor", title: "Humor", emojis: [
            "😂", "😤", "🙌", "👏", "😁"
        ])
    ]

    /// Flat list (unique, stable section order) for defaults and Firestore normalization.
    static var all: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for section in paletteSections {
            for e in section.emojis where seen.insert(e).inserted {
                out.append(e)
            }
        }
        return out
    }

    static var defaultCounts: [String: Int] {
        Dictionary(uniqueKeysWithValues: all.map { ($0, 0) })
    }

    /// Full palette ordered by usage on the post (most used first), then catalog order.
    static func paletteOrdered(reactionCounts: [String: Int]) -> [String] {
        all.sorted { a, b in
            let ca = reactionCounts[a] ?? 0
            let cb = reactionCounts[b] ?? 0
            if ca != cb { return ca > cb }
            guard let ia = all.firstIndex(of: a), let ib = all.firstIndex(of: b) else { return false }
            return ia < ib
        }
    }
}
