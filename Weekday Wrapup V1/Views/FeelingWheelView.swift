import SwiftUI

struct FeelingWheelView: View {
    @Binding var selectedEmotions: Set<String>
    
    // Static emotion map for use by other views
    static let emotionMap: [String: [String]] = [
        "Happy": ["Playful", "Content", "Interested", "Proud", "Accepted", "Powerful", "Peaceful", "Trusting", "Optimistic"],
        "Surprised": ["Startled", "Confused", "Amazed", "Excited", "Energetic", "Eager", "Awe", "Astonished"],
        "Bad": ["Bored", "Busy", "Stressed", "Tired", "Rushed", "Vulnerable", "Overwhelmed"],
        "Fearful": ["Scared", "Anxious", "Insecure", "Weak", "Rejected", "Threatened", "Nervous", "Worried"],
        "Angry": ["Critical", "Distant", "Frustrated", "Aggressive", "Mad", "Hostile", "Hurt", "Jealous"],
        "Disgusted": ["Disapproving", "Disappointed", "Awful", "Repelled", "Horrified", "Hesitant", "Loathing"],
        "Sad": ["Guilty", "Abandoned", "Despair", "Depressed", "Lonely", "Bored", "Ashamed", "Ignored"],
    ]
    
    // Private reference to emotionMap for internal use
    private var emotions: [String: [String]] { Self.emotionMap }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size * 0.35
            
            ZStack {
                // Core emotions
                ForEach(Array(emotions.keys.enumerated()), id: \.element) { index, emotion in
                    let angle = 2 * Double.pi * Double(index) / Double(emotions.count)
                    let position = CGPoint(
                        x: center.x + radius * cos(angle),
                        y: center.y + radius * sin(angle)
                    )
                    
                    // Main emotion bubble
                    EmotionBubble(
                        text: emotion,
                        isSelected: selectedEmotions.contains(emotion),
                        color: emotionColor(for: emotion)
                    )
                    .position(position)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            toggleEmotion(emotion)
                        }
                    }
                    
                    // Sub-emotions
                    if let subEmotions = emotions[emotion] {
                        ForEach(Array(subEmotions.enumerated()), id: \.element) { subIndex, subEmotion in
                            let subCount = Double(subEmotions.count)
                            let spreadAngle = Double.pi / 3 // 60 degrees
                            let subAngle = angle - spreadAngle/2 + spreadAngle * Double(subIndex) / (subCount - 1)
                            let subRadius = radius * 1.6
                            let subPosition = CGPoint(
                                x: center.x + subRadius * cos(subAngle),
                                y: center.y + subRadius * sin(subAngle)
                            )
                            
                            EmotionBubble(
                                text: subEmotion,
                                isSelected: selectedEmotions.contains(subEmotion),
                                color: emotionColor(for: emotion).opacity(0.7),
                                isSubEmotion: true
                            )
                            .position(subPosition)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    toggleEmotion(subEmotion)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func toggleEmotion(_ emotion: String) {
        if selectedEmotions.contains(emotion) {
            selectedEmotions.remove(emotion)
        } else {
            selectedEmotions.insert(emotion)
        }
    }
    
    private func emotionColor(for emotion: String) -> Color {
        switch emotion {
        case "Happy": return .yellow
        case "Surprised": return .orange
        case "Bad": return .gray
        case "Fearful": return .green
        case "Angry": return .red
        case "Disgusted": return .purple
        case "Sad": return .blue
        default: return .gray
        }
    }
}

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