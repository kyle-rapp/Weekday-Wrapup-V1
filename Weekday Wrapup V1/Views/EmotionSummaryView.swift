import SwiftUI

struct EmotionSummaryView: View {
    let emotions: Set<String>
    
    // Add reference to emotion colors using regular dictionary
    let emotionColors: [String: Color] = [
        "Mad": .red.opacity(0.8),
        "Scared": .purple.opacity(0.8),
        "Joyful": .yellow.opacity(0.8),
        "Powerful": .orange.opacity(0.8),
        "Peaceful": .green.opacity(0.8),
        "Sad": .blue.opacity(0.8)
    ]
    
    // Function to determine color for secondary emotions
    func colorForEmotion(_ emotion: String) -> Color {
        // Check each primary emotion's secondary emotions to find the matching color
        for (primary, secondaries) in FeelingWheelView.emotionMap {
            if secondaries.contains(emotion) {
                return emotionColors[primary] ?? .blue.opacity(0.8)
            }
        }
        // If it's a primary emotion, return its color directly
        return emotionColors[emotion] ?? .blue.opacity(0.8)
    }
    
    func textColor(for emotion: String) -> Color {
        // Check if it's a primary emotion
        if emotion == "Joyful" {
            return Color(.sRGB, red: 0.3, green: 0.3, blue: 0.0, opacity: 1)
        }
        // Check secondary emotions
        for (primary, secondaries) in FeelingWheelView.emotionMap {
            if secondaries.contains(emotion) && primary == "Joyful" {
                return Color(.sRGB, red: 0.3, green: 0.3, blue: 0.0, opacity: 1)
            }
        }
        return .white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Emotions:")
                .font(.headline)
                .foregroundColor(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(Array(emotions).sorted(), id: \.self) { emotion in
                    Text(emotion)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textColor(for: emotion))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(colorForEmotion(emotion))
                        )
                }
            }
        }
    }
}

// Helper view for wrapping emotion tags
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(width: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(width: bounds.width, spacing: spacing, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                    y: bounds.minY + result.positions[index].y),
                         proposal: ProposedViewSize(result.sizes[index]))
        }
    }
    
    struct FlowResult {
        var sizes: [CGSize] = []
        var positions: [CGPoint] = []
        var size: CGSize = .zero
        
        init(width: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxWidth: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > width && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                sizes.append(size)
                positions.append(CGPoint(x: currentX, y: currentY))
                
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                maxWidth = max(maxWidth, currentX)
            }
            
            size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
} 