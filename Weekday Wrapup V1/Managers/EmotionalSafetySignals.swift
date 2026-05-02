import Foundation

/// FILE: Managers/EmotionalSafetySignals.swift
/// Gentle detection of heavy emotional language — supportive UI only, not diagnostics.

enum EmotionalSafetySignals {

    static let triggerTokens: [String] = [
        "depressed", "hopeless", "lonely", "overwhelmed"
    ]

    static func signalsSupport(emotion: String, keywords: [String], extraText: String) -> Bool {
        let blob = ([emotion] + keywords + [extraText])
            .joined(separator: " ")
            .lowercased()
        return triggerTokens.contains { blob.contains($0) }
    }

    static func containsCrisisLanguage(_ text: String) -> Bool {
        let blob = text.lowercased()
        let phrases = [
            "suicide",
            "kill myself",
            "don't want to live",
            "dont want to live"
        ]
        return phrases.contains(where: { blob.contains($0) })
    }
}
