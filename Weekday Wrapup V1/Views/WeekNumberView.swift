import SwiftUI

struct WeekNumberView: View {
    let weekNumber: Int
    @Binding var emoji: String
    @State private var showEmojiPicker = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Week \(weekNumber)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Button(action: { showEmojiPicker = true }) {
                Text(emoji.isEmpty ? "😊" : emoji)
                    .font(.title3)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView(selectedEmoji: $emoji)
        }
    }
}

struct EmojiPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedEmoji: String
    
    // Categorized emojis
    let emojiCategories = [
        ("Mood", [
            "😊", "🥰", "😌", "😎", "🤩", "🥳",
            "😤", "😫", "😮‍💨", "😪", "😴", "😵‍💫",
            "🤔", "🤨", "😏", "🙄", "😬", "😶‍🌫️"
        ]),
        ("Activities", [
            "💪", "🧘‍♀️", "🏃‍♀️", "🚶‍♀️", "🧠", "📚",
            "🎨", "🎭", "🎮", "🎯", "⚡️", "💭"
        ]),
        ("Nature", [
            "🌟", "✨", "💫", "🌙", "☀️", "🌈",
            "🌸", "🌺", "🌻", "🍀", "🌿", "🌱"
        ]),
        ("Hearts", [
            "❤️", "🧡", "💛", "💚", "💙", "💜",
            "🤎", "🖤", "🤍", "💝", "💖", "💗"
        ]),
        ("Weather", [
            "☀️", "🌤", "⛅️", "🌥", "☁️", "🌧",
            "⛈", "🌩", "🌨", "❄️", "💨", "🌪"
        ]),
        ("Symbols", [
            "✨", "💫", "⭐️", "🌟", "✴️", "❇️",
            "💥", "💢", "💤", "💭", "🔮", "🎯"
        ])
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Select Emoji")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(emojiCategories, id: \.0) { category, emojis in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category)
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: 44), spacing: 12)
                                ],
                                spacing: 12
                            ) {
                                ForEach(emojis, id: \.self) { emoji in
                                    Button(action: {
                                        selectedEmoji = emoji
                                        dismiss()
                                    }) {
                                        Text(emoji)
                                            .font(.system(size: 28))
                                            .frame(width: 44, height: 44)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedEmoji == emoji ?
                                                          Color.accentColor.opacity(0.1) :
                                                            Color(.systemBackground))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(
                                                        selectedEmoji == emoji ?
                                                        Color.accentColor : Color.clear,
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

// Preview
struct WeekNumberView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            WeekNumberView(weekNumber: 1, emoji: .constant("😊"))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 