import SwiftUI

/// FILE: Views/Grow/DayDetailView.swift
/// Inline day summary + full navigation detail for Grow history.

struct DayDetailCompact: View {
    let entry: CheckInData

    private var emotionLabel: String {
        let sorted = entry.selectedEmotions.sorted()
        if sorted.isEmpty { return "Unknown" }
        return sorted.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.date, style: .date)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.colors.textPrimary)
                if entry.manualEntry {
                    Text("Manual")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppTheme.colors.mist))
                }
                Spacer()
                Text("Intensity \(entry.intensity.map(String.init) ?? "—")")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.colors.textSecondary)
            }

            Text(emotionLabel)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.colors.textPrimary)

            if let tags = entry.helpfulTags, !tags.isEmpty {
                FlowTagRow(title: "What helped", tags: tags)
            }

            if !entry.emotionalInsight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(entry.emotionalInsight)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.colors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct FlowTagRow: View {
    let title: String
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.colors.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { t in
                        TagChipView(title: t)
                    }
                }
            }
        }
    }
}

struct DayDetailView: View {
    let entry: CheckInData

    private var emotionLabel: String {
        let sorted = entry.selectedEmotions.sorted()
        if sorted.isEmpty { return "Unknown" }
        return sorted.joined(separator: ", ")
    }

    private var noteText: String? {
        let insight = entry.emotionalInsight.trimmingCharacters(in: .whitespacesAndNewlines)
        let helped = entry.whatHelped?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !insight.isEmpty && !helped.isEmpty {
            return "\(insight)\n\nWhat helped: \(helped)"
        }
        if !insight.isEmpty { return insight }
        if !helped.isEmpty { return "What helped: \(helped)" }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(entry.date, style: .date)
                        .font(.headline)
                        .foregroundStyle(AppTheme.colors.textPrimary)

                    Text(emotionLabel)
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Intensity: \(entry.intensity.map(String.init) ?? "—")")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.colors.textSecondary)

                    if entry.manualEntry {
                        Text("Logged manually from calendar")
                            .font(.caption)
                            .foregroundStyle(AppTheme.colors.textSecondary)
                    }

                    if let tags = entry.helpfulTags, !tags.isEmpty {
                        FlowTagRow(title: "What helped", tags: tags)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let noteText {
                        Text(noteText)
                            .font(.body)
                            .foregroundStyle(AppTheme.colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .background(AppTheme.colors.secondaryBackground)
            .navigationTitle("Day detail")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
