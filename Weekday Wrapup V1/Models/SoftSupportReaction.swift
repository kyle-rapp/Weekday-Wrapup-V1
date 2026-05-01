import Foundation

/// FILE: Models/SoftSupportReaction.swift
/// Low-pressure “soft social” reactions stored under `posts/{postId}/reactions/{docId}`.

enum SoftSupportReactionKind: String, CaseIterable, Codable, Hashable {
    case hereForYou = "here_for_you"
    case proud = "proud"
    case thinking = "thinking"

    var emoji: String {
        switch self {
        case .hereForYou: return "❤️"
        case .proud: return "💪"
        case .thinking: return "🌙"
        }
    }

    var shortLabel: String {
        switch self {
        case .hereForYou: return "I'm here for you"
        case .proud: return "Proud of you"
        case .thinking: return "Thinking of you"
        }
    }

    /// Doc id: `{userId}__{rawValue}` (one document per user per reaction type per post).
    static func documentId(userId: String, kind: SoftSupportReactionKind) -> String {
        "\(userId)__\(kind.rawValue)"
    }
}
