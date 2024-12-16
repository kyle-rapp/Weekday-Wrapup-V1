import SwiftUI

// Common styles following Apple Design Guidelines
private struct InputViewStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 44) // Minimum touch target size
            .background(AppTheme.colors.background)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.colors.sand.opacity(0.3), lineWidth: 1)
            )
    }
}

private struct HeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundColor(.primary)
            .frame(height: 44) // Consistent with minimum touch target
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PlaceholderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundColor(.secondary.opacity(0.7))
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
    }
}

struct InsightInputView: View {
    @Binding var text: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    private let placeholder = "When I was doing X, I felt Y, which then made me want to Z, but what I really needed was A"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AppTheme.colors.moss)
                Text("Emotional Insight")
                    .modifier(HeaderStyle())
            }
            
            TextEditor(text: $text)
                .font(.body)
                .focused($isFocused)
                .frame(minHeight: 100)
                .modifier(InputViewStyle())
                .tint(AppTheme.colors.primary)
                .overlay(
                    Group {
                        if text.isEmpty {
                            Text(placeholder)
                                .modifier(PlaceholderStyle())
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
                .onChange(of: isFocused) { newValue in
                    isEditing = newValue
                }
        }
    }
}

struct WhoopsInputView: View {
    @Binding var text: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    private let placeholder = "Got a dog or Found a pretty flower"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppTheme.colors.ocean)
                Text("Whoops")
                    .modifier(HeaderStyle())
            }
            
            TextEditor(text: $text)
                .font(.body)
                .focused($isFocused)
                .frame(minHeight: 80)
                .modifier(InputViewStyle())
                .tint(AppTheme.colors.primary)
                .overlay(
                    Group {
                        if text.isEmpty {
                            Text(placeholder)
                                .modifier(PlaceholderStyle())
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
                .onChange(of: isFocused) { newValue in
                    isEditing = newValue
                }
        }
    }
}

struct WeeklyGoalInputView: View {
    @Binding var text: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    private let placeholder = "Call mom"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .foregroundStyle(AppTheme.colors.bark)
                Text("Week Goal")
                    .modifier(HeaderStyle())
            }
            
            TextEditor(text: $text)
                .font(.body)
                .focused($isFocused)
                .frame(minHeight: 80)
                .modifier(InputViewStyle())
                .tint(AppTheme.colors.primary)
                .overlay(
                    Group {
                        if text.isEmpty {
                            Text(placeholder)
                                .modifier(PlaceholderStyle())
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
                .onChange(of: isFocused) { newValue in
                    isEditing = newValue
                }
        }
    }
}

struct PoopsInputView: View {
    @Binding var text: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    private let placeholder = "Longhorns lost to Georgia"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.square.filled.on.square")
                    .foregroundStyle(AppTheme.colors.ocean)
                Text("Poops")
                    .modifier(HeaderStyle())
            }
            
            TextEditor(text: $text)
                .font(.body)
                .focused($isFocused)
                .frame(minHeight: 80)
                .modifier(InputViewStyle())
                .tint(AppTheme.colors.primary)
                .overlay(
                    Group {
                        if text.isEmpty {
                            Text(placeholder)
                                .modifier(PlaceholderStyle())
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
                .onChange(of: isFocused) { newValue in
                    isEditing = newValue
                }
        }
    }
}

struct MonthlyGoalInputView: View {
    @Binding var text: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    private let placeholder = "Learn to juggle"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(AppTheme.colors.clay)
                Text("Month Goal")
                    .modifier(HeaderStyle())
            }
            
            TextEditor(text: $text)
                .font(.body)
                .focused($isFocused)
                .frame(minHeight: 80)
                .modifier(InputViewStyle())
                .tint(AppTheme.colors.primary)
                .overlay(
                    Group {
                        if text.isEmpty {
                            Text(placeholder)
                                .modifier(PlaceholderStyle())
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
                .onChange(of: isFocused) { newValue in
                    isEditing = newValue
                }
        }
    }
}

// Custom blinking cursor view with improved visibility
struct BlinkingCursor: View {
    @State private var isVisible = true
    
    var body: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: 2, height: 20)
            .opacity(isVisible ? 1 : 0)
            .animation(
                Animation
                    .easeInOut(duration: 0.6)
                    .repeatForever(),
                value: isVisible
            )
            .onAppear {
                isVisible.toggle()
            }
    }
}

// Preview
struct InputViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode
            VStack(spacing: 20) {
                InsightInputView(text: .constant(""))
                WhoopsInputView(text: .constant(""))
                WeeklyGoalInputView(text: .constant(""))
            }
            .padding()
            .previewDisplayName("Light Mode")
            
            // Dark mode
            VStack(spacing: 20) {
                InsightInputView(text: .constant("Sample text"))
                WhoopsInputView(text: .constant(""))
                WeeklyGoalInputView(text: .constant(""))
            }
            .padding()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
} 