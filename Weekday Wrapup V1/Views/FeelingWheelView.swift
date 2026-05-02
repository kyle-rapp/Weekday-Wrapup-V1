import SwiftUI
import UIKit

// MARK: - Public API

struct FeelingWheelView: View {
    @Binding var selectedEmotions: Set<String>
    @State private var selectedPrimaryIndex: Int? = nil
    private let maxSecondarySelections = 5

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let wheelRadius = side / 2

            VStack(spacing: 12) {
                Text("How are you feeling today?")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                Text("Tip: pick up to 3 that stand out (max 5).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                EmotionWheelCanvas(
                    wheelRadius: wheelRadius,
                    selectedEmotions: $selectedEmotions,
                    selectedPrimaryIndex: $selectedPrimaryIndex,
                    maxSecondarySelections: maxSecondarySelections
                )
                .frame(width: side, height: side)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Used by EmotionSummaryView and others
    static let emotionMap: [String: [String]] = WheelData.primaryToSecondaries
}

// MARK: - Data from reference image (classic psychology feeling wheel)

private enum WheelData {
    /// Clockwise from top; preserves opposites: Joyful↔Sad, Powerful↔Mad, Peaceful↔Scared
    static let primaryOrder: [String] = ["Joyful", "Powerful", "Peaceful", "Sad", "Mad", "Scared"]

    static let primaryToSecondaries: [String: [String]] = [
        "Joyful": ["excited", "sensuous", "energetic", "cheerful", "creative", "hopeful"],
        "Powerful": ["aware", "proud", "respected", "appreciated", "important", "faithful"],
        "Peaceful": ["content", "thoughtful", "intimate", "loving", "trusting", "nurturing"],
        "Sad": ["lonely", "bored", "tired", "depressed", "ashamed", "guilty"],
        "Mad": ["hurt", "hostile", "angry", "frustrated", "selfish", "hateful"],
        "Scared": ["critical", "confused", "rejected", "helpless", "submissive", "insecure"],
    ]

    /// All primary + secondary labels on the wheel (for clearing selection).
    static var allWheelLabels: Set<String> {
        var s = Set<String>()
        for p in primaryOrder {
            s.insert(p)
            for sub in primaryToSecondaries[p] ?? [] {
                s.insert(sub)
            }
        }
        return s
    }

    static func color(for primary: String) -> Color {
        switch primary {
        case "Joyful": return Color(red: 0.97, green: 0.80, blue: 0.82)   // #F7CCD0
        case "Powerful": return Color(red: 1.0, green: 0.84, blue: 0.38)   // #FFD662
        case "Peaceful": return Color(red: 0.73, green: 0.88, blue: 0.62)   // #B9E09F
        case "Sad": return Color(red: 0.63, green: 0.82, blue: 0.92)      // #A0D2EB
        case "Mad": return Color(red: 0.88, green: 0.62, blue: 0.44)       // #E09F70
        case "Scared": return Color(red: 0.91, green: 0.81, blue: 0.72)    // #E8CFB8
        default: return .gray
        }
    }

    /// Lighter shade for secondary ring (same hue, more pastel)
    static func secondaryColor(for primary: String) -> Color {
        color(for: primary).opacity(0.88)
    }
}

// MARK: - Radial geometry

private struct WheelLayout {
    let center: CGPoint
    let wheelRadius: CGFloat
    /// Inner ring outer edge (~45% of wheel) – primary wedges go from center to here
    let innerRadius: CGFloat
    /// Outer ring outer edge (~85%) – secondary wedges go from innerRadius to here
    let outerRadius: CGFloat
    let primarySpanDegrees: Double = 60
    var secondarySpanDegrees: Double { primarySpanDegrees / 6 }

    init(center: CGPoint, wheelRadius: CGFloat) {
        self.center = center
        self.wheelRadius = wheelRadius
        self.innerRadius = wheelRadius * 0.55
        self.outerRadius = wheelRadius * 0.95
    }

    func primaryStart(index: Int) -> Double { -90 + Double(index) * primarySpanDegrees }
    func primaryEnd(index: Int) -> Double { primaryStart(index: index) + primarySpanDegrees }
    func secondaryStart(primaryIndex: Int, secondaryIndex: Int) -> Double {
        primaryStart(index: primaryIndex) + Double(secondaryIndex) * secondarySpanDegrees
    }
    func secondaryEnd(primaryIndex: Int, secondaryIndex: Int) -> Double {
        secondaryStart(primaryIndex: primaryIndex, secondaryIndex: secondaryIndex) + secondarySpanDegrees
    }
}

private func polar(center: CGPoint, radius: CGFloat, degrees: Double) -> CGPoint {
    let rad = CGFloat(degrees * .pi / 180)
    return CGPoint(x: center.x + cos(rad) * radius, y: center.y + sin(rad) * radius)
}

private func labelPosition(
    center: CGPoint,
    innerRadius: CGFloat,
    outerRadius: CGFloat,
    startAngle: Double,
    endAngle: Double
) -> (CGPoint, Double) {
    let midAngle = (startAngle + endAngle) / 2
    let radius = (innerRadius + outerRadius) / 2
    let position = polar(center: center, radius: radius, degrees: midAngle)

    var rotation = midAngle
    if rotation > 90 && rotation < 270 {
        rotation += 180
    }

    return (position, rotation)
}

/// Returns black or white for readable contrast on the given background color
private func readableTextColor(for color: Color) -> Color {
    let uiColor = UIColor(color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

    let brightness = (red * 299 + green * 587 + blue * 114) / 1000
    return brightness > 0.6 ? .black : .white
}

/// Rotation so label follows wedge direction (right-side horizontal, left-side flipped for readability)
private func radialRotation(degrees: Double) -> Double {
    var angle = degrees
    if angle > 90 && angle < 270 {
        angle += 180
    }
    return angle
}

// MARK: - Annulus wedge (inner and outer ring segments)

private struct AnnulusWedgeShape: Shape {
    var startDegrees: Double
    var endDegrees: Double
    var innerR: CGFloat
    var outerR: CGFloat

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.move(to: polar(center: c, radius: innerR, degrees: startDegrees))
        p.addArc(center: c, radius: outerR, startAngle: .degrees(startDegrees), endAngle: .degrees(endDegrees), clockwise: false)
        p.addLine(to: polar(center: c, radius: innerR, degrees: endDegrees))
        if innerR > 0 {
            p.addArc(center: c, radius: innerR, startAngle: .degrees(endDegrees), endAngle: .degrees(startDegrees), clockwise: true)
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Multi-ring wheel canvas

private struct EmotionWheelCanvas: View {
    let wheelRadius: CGFloat
    @Binding var selectedEmotions: Set<String>
    @Binding var selectedPrimaryIndex: Int?
    let maxSecondarySelections: Int

    private var center: CGPoint { CGPoint(x: wheelRadius, y: wheelRadius) }
    private var layout: WheelLayout { WheelLayout(center: center, wheelRadius: wheelRadius) }
    private let anim = Animation.easeInOut(duration: 0.32)

    var body: some View {
        ZStack {
            // Layer 1: Primary (inner) ring – 6 wedges from center to innerRadius
            primaryRing
                .zIndex(0)
            // Layer 2: Secondary (outer) ring – 36 wedges within each primary’s angle, innerRadius to outerRadius
            secondaryRing
                .zIndex(1)
            // Layer 3: Primary labels (inside inner wedges)
            primaryLabels
                .zIndex(2)
            // Layer 4: Secondary labels (inside outer wedges)
            secondaryLabels
                .zIndex(3)
            // Layer 5: Center circle
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: layout.innerRadius * 0.05, height: layout.innerRadius * 0.05)
                .zIndex(4)
        }
        .frame(width: wheelRadius * 2, height: wheelRadius * 2)
        .contentShape(Circle())
        .drawingGroup()
        .clipped()
        .overlay(
            Circle()
                .stroke(Color.black.opacity(0.05), lineWidth: 2)
        )
    }

    // MARK: Primary ring

    private var primaryRing: some View {
        ForEach(Array(WheelData.primaryOrder.enumerated()), id: \.offset) { index, name in
            let start = layout.primaryStart(index: index)
            let end = layout.primaryEnd(index: index)
            let wedge = AnnulusWedgeShape(startDegrees: start, endDegrees: end, innerR: 0, outerR: layout.innerRadius)
            let isSelected = selectedPrimaryIndex == index
            let isFaded = selectedPrimaryIndex != nil && selectedPrimaryIndex != index

            wedge
                .fill(WheelData.color(for: name))
                .overlay(wedge.stroke(Color.white, lineWidth: 1.2))
                .shadow(color: isSelected ? WheelData.color(for: name).opacity(0.4) : .clear, radius: isSelected ? 6 : 0)
                .opacity(isFaded ? 0.28 : 1)
                .scaleEffect(isSelected ? 1.05 : 1)
                .animation(anim, value: isFaded)
                .animation(anim, value: isSelected)
                .contentShape(wedge)
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(anim) {
                        if selectedPrimaryIndex == index {
                            selectedPrimaryIndex = nil
                            selectedEmotions.remove(name)
                            for sub in WheelData.primaryToSecondaries[name] ?? [] {
                                selectedEmotions.remove(sub)
                            }
                        } else {
                            for label in WheelData.allWheelLabels {
                                selectedEmotions.remove(label)
                            }
                            selectedPrimaryIndex = index
                            selectedEmotions.insert(name)
                        }
                    }
                }
        }
    }

    // MARK: Secondary ring – each wedge stays inside its primary’s 60° slice

    private var secondaryRing: some View {
        ForEach(Array(WheelData.primaryOrder.enumerated()), id: \.offset) { primaryIndex, primaryName in
            let secondaries = WheelData.primaryToSecondaries[primaryName] ?? []
            let canTap = selectedPrimaryIndex == primaryIndex

            ForEach(Array(secondaries.enumerated()), id: \.offset) { secondaryIndex, label in
                let start = layout.secondaryStart(primaryIndex: primaryIndex, secondaryIndex: secondaryIndex)
                let end = layout.secondaryEnd(primaryIndex: primaryIndex, secondaryIndex: secondaryIndex)
                let wedge = AnnulusWedgeShape(
                    startDegrees: start,
                    endDegrees: end,
                    innerR: layout.innerRadius,
                    outerR: layout.outerRadius
                )
                let isOn = selectedEmotions.contains(label)
                let faded = selectedPrimaryIndex != nil && selectedPrimaryIndex != primaryIndex

                wedge
                    .fill(WheelData.secondaryColor(for: primaryName).opacity(isOn ? 0.9 : 0.75))
                    .overlay(wedge.stroke(Color.white, lineWidth: 1))
                    .opacity(faded ? 0.3 : 1)
                    .scaleEffect(isOn ? 1.05 : 1)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isOn)
                    .animation(anim, value: faded)
                    .contentShape(wedge)
                    .allowsHitTesting(canTap)
                    .onTapGesture {
                        guard canTap else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(anim) {
                            if selectedEmotions.contains(label) {
                                selectedEmotions.remove(label)
                            } else {
                                let primary = WheelData.primaryOrder[primaryIndex]
                                let secondaryCount = selectedEmotions.filter { item in
                                    item.caseInsensitiveCompare(primary) != .orderedSame
                                }.count
                                if secondaryCount < maxSecondarySelections {
                                    selectedEmotions.insert(label)
                                }
                            }
                        }
                    }
            }
        }
    }

    // MARK: Primary labels (radial, inside inner wedges)

    private var primaryLabels: some View {
        let labelRadius = layout.innerRadius * 0.65
        return ForEach(Array(WheelData.primaryOrder.enumerated()), id: \.offset) { index, name in
            let start = layout.primaryStart(index: index)
            let end = layout.primaryEnd(index: index)
            let mid = (start + end) / 2
            let pos = polar(center: layout.center, radius: labelRadius, degrees: mid)
            let isFaded = selectedPrimaryIndex != nil && selectedPrimaryIndex != index

            Text(name)
                .font(.system(size: wheelRadius * 0.075, weight: .bold))
                .foregroundColor(readableTextColor(for: WheelData.color(for: name)))
                .position(pos)
                .rotationEffect(.degrees(0))
                .opacity(isFaded ? 0.3 : 1)
                .animation(anim, value: isFaded)
                .allowsHitTesting(false)
        }
    }

    // MARK: Secondary labels (radial, inside outer wedges)

    private var secondaryLabels: some View {
        return ForEach(Array(WheelData.primaryOrder.enumerated()), id: \.offset) { primaryIndex, primaryName in
            let secondaries = WheelData.primaryToSecondaries[primaryName] ?? []
            let faded = selectedPrimaryIndex != nil && selectedPrimaryIndex != primaryIndex

            ForEach(Array(secondaries.enumerated()), id: \.offset) { secondaryIndex, text in
                let start = layout.secondaryStart(primaryIndex: primaryIndex, secondaryIndex: secondaryIndex)
                let end = layout.secondaryEnd(primaryIndex: primaryIndex, secondaryIndex: secondaryIndex)
                let (pos, rotation) = labelPosition(
                    center: layout.center,
                    innerRadius: layout.innerRadius,
                    outerRadius: layout.outerRadius,
                    startAngle: start,
                    endAngle: end
                )

                Text(text)
                    .font(.system(size: max(9, wheelRadius * 0.04), weight: .medium))
                    .foregroundColor(readableTextColor(for: WheelData.secondaryColor(for: primaryName)))
                    .frame(width: (layout.outerRadius - layout.innerRadius) * 0.9)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .rotationEffect(.degrees(rotation), anchor: .center)
                    .position(pos)
                    .opacity(faded ? 0.3 : 1)
                    .animation(anim, value: faded)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Legacy

struct EmotionBubble: View {
    let text: String
    let isSelected: Bool
    let color: Color
    var isSubEmotion: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: isSubEmotion ? 12 : 14, weight: .medium))
            .padding(.horizontal, isSubEmotion ? 8 : 12)
            .padding(.vertical, isSubEmotion ? 4 : 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color : Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
            )
            .foregroundColor(isSelected ? .white : .black)
    }
}
