import SwiftUI

/// FILE: Views/Grow/GrowCalendarPalette.swift
/// Calendar cell color from **primary emotion** + **intensity** (no accidental red for peaceful/loving).

enum GrowCalendarPalette {

    static func color(for emotion: String, intensity: Int?) -> Color {
        let e = emotion.lowercased()
        let level = Double(intensity ?? 5) / 10.0

        if e.contains("peace") || e.contains("calm") || e.contains("love") || e.contains("nurtur") || e.contains("content") || e.contains("trust") {
            return Color.green.opacity(0.3 + level * 0.5)
        } else if e.contains("happy") || e.contains("joy") || e.contains("joyful") || e.contains("cheerful") || e.contains("excited") {
            return Color.yellow.opacity(0.3 + level * 0.5)
        } else if e.contains("sad") || e.contains("hurt") || e.contains("lonely") || e.contains("bored") || e.contains("tired") {
            return Color.blue.opacity(0.3 + level * 0.5)
        } else if e.contains("angry") || e.contains("mad") || e.contains("hostile") || e.contains("frustrated") {
            return Color.red.opacity(0.3 + level * 0.5)
        } else {
            return Color.gray.opacity(0.35 + level * 0.25)
        }
    }

    static func colorForEntry(_ entry: CheckInData?) -> Color {
        guard let entry else {
            return Color.gray.opacity(0.15)
        }
        let label = entry.firstSelectedEmotionLabel
        guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Color.gray.opacity(0.15)
        }
        return color(for: label, intensity: entry.intensity)
    }

    static func dayNumberColor(for entry: CheckInData?) -> Color {
        guard let entry else {
            return AppTheme.colors.textSecondary.opacity(0.65)
        }
        let label = entry.firstSelectedEmotionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else {
            return AppTheme.colors.textSecondary.opacity(0.65)
        }
        return Color.primary.opacity(0.85)
    }
}
