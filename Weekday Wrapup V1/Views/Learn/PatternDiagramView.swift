import SwiftUI

/// FILE: Views/Learn/PatternDiagramView.swift
/// Fixed-width mobile diagram for the Learn tab pattern section.

struct PatternDiagramView: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("THE PATTERN")
                .font(.title3.weight(.heavy))
                .tracking(1.6)
                .foregroundStyle(Color.black.opacity(0.82))
                .frame(maxWidth: .infinity)

            HStack(alignment: .center, spacing: 8) {
                leftColumn
                    .frame(width: 122)

                centerEscape
                    .frame(width: 48)

                rightColumn
                    .frame(width: 122)
            }

            Text("Understanding the need underneath the feeling is where the pattern starts to change.")
                .font(.footnote)
                .foregroundStyle(AppTheme.colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.colors.sand.opacity(0.32),
                            AppTheme.colors.background,
                            AppTheme.colors.mist.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.colors.sand.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: AppTheme.colors.bark.opacity(0.08), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The pattern: emotional trigger leads to unmet need, unmet need can lead to negative coping, negative coping can lead to self-abandonment, and self-abandonment loops back into emotional triggers. Breaking the pattern starts by understanding your need, choosing healthy coping, and practicing self-advocacy.")
    }

    private var leftColumn: some View {
        VStack(spacing: 6) {
            PatternNode(text: "Emotional\nTrigger", style: .stuck)
            DownArrow(color: AppTheme.colors.bark)
            PatternNode(text: "Unmet\nNeed", style: .stuck)
            DownArrow(color: AppTheme.colors.bark)
            PatternNode(text: "Negative\nCoping", style: .stuck)
            DownArrow(color: AppTheme.colors.bark)
            PatternNode(text: "Self-\nAbandonment", style: .stuck)

            HStack(spacing: 4) {
                Text("↻ repeats")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.black.opacity(0.70))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(width: 112)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.colors.clay.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.colors.clay.opacity(0.24), lineWidth: 1)
            )
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.colors.clay.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.colors.clay.opacity(0.20), lineWidth: 1)
        )
    }

    private var centerEscape: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 80)

            Text("→")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Color(red: 0.12, green: 0.45, blue: 0.42))
                .frame(width: 34, height: 26)

            Text("break\nthe loop")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.colors.ocean)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(width: 48)

            Text("→")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Color(red: 0.12, green: 0.45, blue: 0.42))
                .frame(width: 34, height: 26)

            Spacer(minLength: 80)
        }
        .accessibilityHidden(true)
    }

    private var rightColumn: some View {
        VStack(spacing: 6) {
            Text("BREAKING\nTHE PATTERN")
                .font(.caption2.weight(.heavy))
                .tracking(0.5)
                .foregroundStyle(Color.black.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(width: 112)
                .frame(minHeight: 34)

            PatternNode(text: "Understand\nYour Need", style: .growth)
            DownArrow(color: AppTheme.colors.pine)
            PatternNode(text: "Healthy\nCoping", style: .growth)
            DownArrow(color: AppTheme.colors.pine)
            PatternNode(text: "Self-\nAdvocacy", style: .growth)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.colors.sage.opacity(0.18),
                            AppTheme.colors.ocean.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.colors.sage.opacity(0.28), lineWidth: 1)
        )
    }
}

private enum PatternNodeStyle {
    case stuck
    case growth
}

private struct PatternNode: View {
    let text: String
    let style: PatternNodeStyle

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.colors.textPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .frame(width: 112)
            .frame(minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(fillColor)
                    .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1.2)
            )
            .accessibilityLabel(text.replacingOccurrences(of: "\n", with: " "))
    }

    private var fillColor: Color {
        switch style {
        case .stuck:
            return Color(red: 0.94, green: 0.88, blue: 0.82).opacity(0.98)
        case .growth:
            return Color(red: 0.82, green: 0.92, blue: 0.86)
        }
    }

    private var strokeColor: Color {
        switch style {
        case .stuck:
            return AppTheme.colors.clay.opacity(0.42)
        case .growth:
            return Color(red: 0.20, green: 0.50, blue: 0.42).opacity(0.55)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .stuck:
            return AppTheme.colors.bark.opacity(0.06)
        case .growth:
            return AppTheme.colors.pine.opacity(0.08)
        }
    }
}

private struct DownArrow: View {
    let color: Color

    var body: some View {
        Text("↓")
            .font(.system(size: 22, weight: .heavy))
            .foregroundStyle(Color.black.opacity(0.75))
            .frame(height: 22)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Pattern Diagram") {
    ScrollView {
        PatternDiagramView()
            .padding()
    }
    .background(AppTheme.colors.secondaryBackground)
}
#endif
