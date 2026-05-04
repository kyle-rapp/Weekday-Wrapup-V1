import Foundation

struct EmotionalPattern: Codable, Equatable {
    let kind: String
    let message: String
    let suggestedActions: [String]
}
