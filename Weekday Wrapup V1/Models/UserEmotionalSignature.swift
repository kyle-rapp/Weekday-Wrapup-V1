import Foundation
import FirebaseFirestore

struct UserEmotionalSignature: Codable, Equatable {
    var averageIntensity: Double
    var topEmotions: [String]
    var topHelpfulTags: [String]
    var sampleSize: Int
    var updatedAt: Date?

    init(
        averageIntensity: Double = 0,
        topEmotions: [String] = [],
        topHelpfulTags: [String] = [],
        sampleSize: Int = 0,
        updatedAt: Date? = nil
    ) {
        self.averageIntensity = averageIntensity
        self.topEmotions = topEmotions
        self.topHelpfulTags = topHelpfulTags
        self.sampleSize = sampleSize
        self.updatedAt = updatedAt
    }

    func asFirestoreDictionary() -> [String: Any] {
        [
            "averageIntensity": averageIntensity,
            "topEmotions": topEmotions,
            "topHelpfulTags": topHelpfulTags,
            "sampleSize": sampleSize,
            "updatedAt": Timestamp(date: updatedAt ?? Date())
        ]
    }
}
