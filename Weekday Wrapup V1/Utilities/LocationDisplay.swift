import Foundation

/// FILE: Utilities/LocationDisplay.swift
/// Never show street-level detail—prefer a single city-style line.

enum LocationDisplay {
    /// Takes the first comma-separated segment, or first line, trimmed.
    static func coarse(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let first = trimmed.split(separator: ",").first {
            let s = first.trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : s
        }
        return trimmed
    }
}
