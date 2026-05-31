import Foundation

/// FILE: Managers/CheckInContextualResources.swift
/// Contextual quote + resource cards for the after-share recommendation popup.

struct ContextualCheckInResource: Identifiable, Equatable {
    let id: String
    let quote: String
    let title: String
    let url: String

    var therapyResource: TherapyResource {
        TherapyResource(title: title, url: url, tags: [])
    }
}

enum CheckInContextualResources {
    private static let scaredLabels: Set<String> = {
        var labels = Set(["scared", "anxious", "worried", "nervous", "anxiety"])
        if let secondaries = FeelingWheelView.emotionMap["Scared"] {
            labels.formUnion(secondaries.map { $0.lowercased() })
        }
        return labels
    }()

    private static let relationshipKeywords = [
        "relationship", "partner", "girlfriend", "boyfriend", "husband", "wife", "dating"
    ]

    static func isScaredEmotion(_ emotion: String) -> Bool {
        let e = emotion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !e.isEmpty else { return false }
        if scaredLabels.contains(e) { return true }
        return scaredLabels.contains(where: { e.contains($0) })
    }

    static func scaredResource() -> ContextualCheckInResource {
        ContextualCheckInResource(
            id: "scared_overthinker_guide",
            quote: "Make decisions based on how you want to feel, rather than on what you're afraid to experience, and your life will be shaped by your dreams rather than your fears.",
            title: "The Overthinker's Guide to Making Decisions",
            url: "https://josephnguyen.org/collections/books/products/the-overthinkers-guide-to-making-decisions-how-to-make-decisions-without-losing-your-mind?srsltid=AfmBOoqVRy5fapD_Imf0ZcG46wNIySNQwprmiaMKE6Vsm3iQnnV7oDBH"
        )
    }

    static func containsRelationshipKeywords(in text: String) -> Bool {
        let normalized = text.lowercased()
        return relationshipKeywords.contains { normalized.contains($0) }
    }

    static func relationshipResource() -> ContextualCheckInResource {
        ContextualCheckInResource(
            id: "relationship_hold_me_tight",
            quote: "The cycle is the bad guy. Neither partner is the bad guy.",
            title: "Hold Me Tight",
            url: "https://www.goodreads.com/book/show/2153780.Hold_Me_Tight"
        )
    }

    static func allResources() -> [ContextualCheckInResource] {
        [scaredResource(), relationshipResource()]
    }

    static func contextualResources(
        emotion: String,
        sourceText: String
    ) -> [ContextualCheckInResource] {
        var out: [ContextualCheckInResource] = []
        if isScaredEmotion(emotion) {
            out.append(scaredResource())
        }
        if containsRelationshipKeywords(in: sourceText) {
            out.append(relationshipResource())
        }
        return out
    }
}
