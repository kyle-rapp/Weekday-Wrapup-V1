import Foundation

/// FILE: Models/EmotionEntry.swift
/// Local history snapshot when the user completes a Share check-in (persisted via `EmotionRouter`).

struct EmotionEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let emotions: [String]
}
