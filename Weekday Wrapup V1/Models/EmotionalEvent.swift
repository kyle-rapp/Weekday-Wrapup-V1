import Foundation

enum EmotionalEventType: String, Codable {
    case recommendationInteraction = "recommendation_interaction"
    case dopamineMenuAdded = "dopamine_menu_added"
    case dopamineMenuRemoved = "dopamine_menu_removed"
    case dopamineMenuUsed = "dopamine_menu_used"
    case emotionCheckIn = "emotion_check_in"
    case habitSignal = "habit_signal"
    case postInteraction = "post_interaction"
}

enum ActionType: String, Codable {
    case click
    case add
    case remove
    case complete
    case dismiss
    case save
    case reflect
}

enum EventSource: String, Codable {
    case growTab = "grow_tab"
    case checkInPopup = "check_in_popup"
    case dopamineMenu = "dopamine_menu"
    case feed
    case group
    case profile
}

struct EmotionSnapshot: Codable, Equatable {
    let emotion: String
    let intensity: Double
}

struct StableItem: Codable, Equatable {
    let itemId: String
    let title: String
    let category: String

    static func fromRecommendation(_ recommendation: Recommendation) -> StableItem {
        let category = recommendation.type.rawValue
        return StableItem(
            itemId: StableId.make(prefix: "rec", title: recommendation.title, category: category),
            title: recommendation.title,
            category: category
        )
    }

    static func fromDopamine(title: String, category: String) -> StableItem {
        StableItem(
            itemId: StableId.make(prefix: "dopamine", title: title, category: category),
            title: title,
            category: category
        )
    }
}

struct EmotionalEvent: Codable, Equatable {
    let eventId: String
    let userId: String
    let timestamp: Date

    let eventType: EmotionalEventType

    let emotionBefore: EmotionSnapshot?
    let emotionAfter: EmotionSnapshot?

    let actionType: ActionType
    let itemId: String?
    let itemTitle: String?
    let source: EventSource

    let didHelp: Bool?
    let intensityChange: Double?

    let tags: [String]
    let metadata: [String: String]

    func asFirestoreDictionary() -> [String: Any] {
        var payload: [String: Any] = [
            "eventId": eventId,
            "userId": userId,
            "timestamp": timestamp.timeIntervalSince1970,
            "eventType": eventType.rawValue,
            "actionType": actionType.rawValue,
            "source": source.rawValue,
            "tags": tags,
            "metadata": metadata
        ]
        if let emotionBefore {
            payload["emotionBefore"] = [
                "emotion": emotionBefore.emotion,
                "intensity": emotionBefore.intensity
            ]
        }
        if let emotionAfter {
            payload["emotionAfter"] = [
                "emotion": emotionAfter.emotion,
                "intensity": emotionAfter.intensity
            ]
        }
        if let itemId { payload["itemId"] = itemId }
        if let itemTitle { payload["itemTitle"] = itemTitle }
        if let didHelp { payload["didHelp"] = didHelp }
        if let intensityChange { payload["intensityChange"] = intensityChange }
        return payload
    }
}

enum StableId {
    static func make(prefix: String, title: String, category: String) -> String {
        let normalized = "\(prefix)|\(title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(category.lowercased())"
        let hash = fnv1a64(normalized)
        return "\(prefix)_\(String(hash, radix: 16))"
    }

    private static func fnv1a64(_ input: String) -> UInt64 {
        let prime: UInt64 = 1099511628211
        var hash: UInt64 = 14695981039346656037
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }
}
