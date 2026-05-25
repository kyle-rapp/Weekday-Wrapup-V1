import SwiftUI

/// FILE: Views/Learn/PatternDiagramView.swift
/// Clean text-first pattern diagram for the Learn tab.

struct PatternDiagramView: View {
    private let clayText = Color(red: 0.58, green: 0.24, blue: 0.20)
    private let growthText = Color(red: 0.12, green: 0.45, blue: 0.42)
    private let repeatArrow = Color.black.opacity(0.62)
    private let breakArrow = Color(red: 0.12, green: 0.45, blue: 0.42)

    var body: some View {
        VStack(spacing: 16) {
            Text("THE PATTERN")
                .font(.title2.weight(.heavy))
                .tracking(1.6)
                .foregroundStyle(Color.black.opacity(0.82))
                .frame(maxWidth: .infinity)

            diagramCanvas
                .frame(height: 390)

            Text("Understanding the need underneath the feeling is where the pattern starts to change.")
                .font(.footnote)
                .foregroundStyle(AppTheme.colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.colors.sand.opacity(0.24),
                            AppTheme.colors.background,
                            AppTheme.colors.mist.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.colors.sand.opacity(0.38), lineWidth: 1)
        )
        .shadow(color: AppTheme.colors.bark.opacity(0.07), radius: 14, x: 0, y: 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The pattern: emotional trigger leads to unmet need, unmet need can lead to negative coping, negative coping can lead to self-abandonment, and self-abandonment loops back into emotional triggers. Breaking the pattern starts by understanding your need, choosing healthy coping, and practicing self-advocacy.")
    }

    private var diagramCanvas: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let leftX = width * 0.30
            let rightX = width * 0.74
            let leftArrowX = max(width * 0.08, 24)
            let labelWidth = min(max(width * 0.34, 112), 132)

            let emotionalY: CGFloat = 38
            let unmetY: CGFloat = 112
            let copingY: CGFloat = 188
            let abandonY: CGFloat = 268
            let understandY: CGFloat = 88
            let healthyY: CGFloat = 178
            let advocacyY: CGFloat = 266

            ZStack {
                CleanLoopArrow(
                    start: CGPoint(x: leftArrowX, y: abandonY + 18),
                    end: CGPoint(x: leftArrowX + 10, y: emotionalY + 2),
                    color: repeatArrow
                )
                .allowsHitTesting(false)

                CleanBreakArrow(
                    start: CGPoint(x: leftX + labelWidth * 0.54, y: abandonY + 4),
                    end: CGPoint(x: rightX - labelWidth * 0.40, y: understandY + 4),
                    color: breakArrow
                )
                .allowsHitTesting(false)

               

                PatternTextLabel("Emotional\nTrigger", color: clayText, width: labelWidth)
                    .position(x: leftX, y: emotionalY)
                SmallArrowDown(color: repeatArrow)
                    .position(x: leftX, y: 74)
                PatternTextLabel("Unmet Need", color: clayText, width: labelWidth)
                    .position(x: leftX, y: unmetY)
                SmallArrowDown(color: repeatArrow)
                    .position(x: leftX, y: 150)
                PatternTextLabel("Negative\nCoping", color: clayText, width: labelWidth)
                    .position(x: leftX, y: copingY)
                SmallArrowDown(color: repeatArrow)
                    .position(x: leftX, y: 226)
                PatternTextLabel("Self-\nAbandonment", color: clayText, width: labelWidth)
                    .position(x: leftX, y: abandonY)

                Text("BREAKING\nTHE PATTERN")
                    .font(.caption.weight(.heavy))
                    .tracking(0.7)
                    .foregroundStyle(Color.black.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.82, green: 0.92, blue: 0.86).opacity(0.55))
                    )
                    .position(x: rightX, y: 28)

                PatternTextLabel("Understand\nYour Need", color: growthText, width: labelWidth)
                    .position(x: rightX, y: understandY)
                SmallArrowDown(color: growthText.opacity(0.95))
                    .position(x: rightX, y: 132)
                PatternTextLabel("Healthy\nCoping", color: growthText, width: labelWidth)
                    .position(x: rightX, y: healthyY)
                SmallArrowDown(color: growthText.opacity(0.95))
                    .position(x: rightX, y: 222)
                Text("Self-\nAdvocacy")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.black.opacity(0.86))
                    .multilineTextAlignment(.center)
                    .underline(true, color: Color.black.opacity(0.86))
                    .frame(width: labelWidth)
                    .position(x: rightX, y: advocacyY)
            }
            .frame(width: width, height: geo.size.height)
        }
    }
}

private struct PatternTextLabel: View {
    let text: String
    let color: Color
    let width: CGFloat

    init(_ text: String, color: Color, width: CGFloat) {
        self.text = text
        self.color = color
        self.width = width
    }

    var body: some View {
        Text(text)
            .font(.callout.weight(.heavy))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: width)
    }
}

private struct SmallArrowDown: View {
    let color: Color

    var body: some View {
        Text("↓")
            .font(.system(size: 24, weight: .heavy))
            .foregroundStyle(color)
            .frame(width: 26, height: 28)
            .accessibilityHidden(true)
    }
}

private struct CleanLoopArrow: View {
    let start: CGPoint
    let end: CGPoint
    let color: Color

    var body: some View {
        GeometryReader { _ in
            Path { path in
                path.move(to: start)
                path.addCurve(
                    to: end,
                    control1: CGPoint(x: start.x - 36, y: start.y - 64),
                    control2: CGPoint(x: end.x - 34, y: end.y + 72)
                )
            }
            .stroke(color, style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))

            Text("➤")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
                .rotationEffect(.degrees(-55))
                .position(end)
                .accessibilityHidden(true)
        }
    }
}

private struct CleanBreakArrow: View {
    let start: CGPoint
    let end: CGPoint
    let color: Color

    var body: some View {
        GeometryReader { _ in
            let arrowHeadPoint = end
            let lineEnd = CGPoint(x: end.x - 4, y: end.y + 4)

            Path { path in
                path.move(to: start)
                path.addQuadCurve(
                    to: lineEnd,
                    control: CGPoint(x: (start.x + end.x) / 2 - 2, y: min(start.y, end.y) + 38)
                )
            }
            .stroke(color, style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))

            Text("➤")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(color)
                .rotationEffect(.degrees(-42))
                .position(arrowHeadPoint)
                .accessibilityHidden(true)
        }
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
