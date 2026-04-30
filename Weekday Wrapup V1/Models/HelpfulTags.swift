import Foundation

/// FILE: Models/HelpfulTags.swift
/// Preset “what helped” tags for check-ins (multi-select).

enum HelpfulTags {
    /// Core retention presets (aligned with Share “What helped?” UI).
    static let presets: [String] = [
        "Music", "Exercise", "Friends", "Sleep", "Journaling", "Nature",
        "Work", "Therapy"
    ]
}
