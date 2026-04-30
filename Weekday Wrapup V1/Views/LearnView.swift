import SwiftUI
import UIKit

/// FILE: Views/LearnView.swift
/// Learn tab: structured cards, feelings wheel, definitions, education, steps, box breathing.

// MARK: - Section shell (mandatory card wrapper)

struct LearnSectionCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.colors.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: AppTheme.colors.bark.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Learn root

struct LearnView: View {
    @EnvironmentObject private var emotionRouter: EmotionRouter

    private var currentEmotionKey: String? {
        emotionRouter.lastSelectedLearn ?? emotionRouter.learnEmotions.first
    }

    private static let guideSteps: [LearnStepItem] = [
        LearnStepItem(
            number: 1,
            title: "Identify what you are feeling",
            description: "Pause and name the strongest emotion you notice, even if it’s broad.",
            systemImage: "brain.head.profile"
        ),
        LearnStepItem(
            number: 2,
            title: "Acknowledge your emotions",
            description: "Let the feeling exist without judging it as good or bad.",
            systemImage: "heart.fill"
        ),
        LearnStepItem(
            number: 3,
            title: "Get curious about the message",
            description: "Ask gently: what might this emotion be trying to tell me?",
            systemImage: "sparkles"
        ),
        LearnStepItem(
            number: 4,
            title: "Build confidence handling it",
            description: "Recall one time you moved through a hard feeling before.",
            systemImage: "leaf"
        ),
        LearnStepItem(
            number: 5,
            title: "Know you can handle it long-term",
            description: "Skills grow with practice; discomfort doesn’t mean you’re failing.",
            systemImage: "moon"
        ),
        LearnStepItem(
            number: 6,
            title: "Take action",
            description: "Pick one small step: a breath, a text, a walk, or a boundary.",
            systemImage: "figure.walk"
        )
    ]

    private static func stepEmoji(for stepNumber: Int) -> String {
        switch stepNumber {
        case 1: return "🧠"
        case 2: return "💛"
        case 3: return "✨"
        case 4: return "🌿"
        case 5: return "🌙"
        case 6: return "🚶"
        default: return "✨"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introSection
                wheelSection
                definitionSection
                wheelExplainedCards
                sixStepGuideSection
                boxBreathingSection
                breathingEducationCards
                emotionInsightsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.visible)
        .background(AppTheme.colors.secondaryBackground.ignoresSafeArea())
        .navigationTitle("Learn")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: Section 1 — Intro

    private var introSection: some View {
        LearnSectionCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Welcome to Emotional Awareness")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.colors.textPrimary)

                Text("Take a moment to connect with yourself and find calm by exploring the interactive Feelings Wheel.")
                    .font(.body)
                    .foregroundStyle(AppTheme.colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                Text("It’s a simple but powerful tool to help you better understand your emotions and improve emotional awareness.")
                    .font(.body)
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tap the wheel below to explore different feelings.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Section 2 — Wheel

    private var wheelSection: some View {
        LearnSectionCard {
            VStack(alignment: .leading, spacing: 18) {
                Label("Explore the wheel", systemImage: "circle.hexagongrid.fill")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.colors.textPrimary)

                Text("Tap a core feeling, then a word on the outer ring.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer(minLength: 0)
                    FeelingWheelView(
                        selectedEmotions: Binding(
                            get: { Set(emotionRouter.learnEmotions) },
                            set: { emotionRouter.updateLearnSelection(Array($0).sorted()) }
                        )
                    )
                        .frame(width: 340, height: 400)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Section 3 — Definition (always visible, non-empty copy)

    private var definitionSection: some View {
        LearnSectionCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("How you're feeling", systemImage: "text.quote")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.colors.textPrimary)

                Group {
                    let trimmedKey = currentEmotionKey?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    if !trimmedKey.isEmpty {
                        Text(trimmedKey)
                            .font(.title.bold())
                            .foregroundStyle(AppTheme.colors.pine)

                        Text(LearnEmotionDefinitionLookup.definition(for: trimmedKey))
                            .font(.body)
                            .foregroundStyle(AppTheme.colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Try this")
                                .font(.headline)
                                .foregroundStyle(AppTheme.colors.textPrimary)
                            ForEach(actionSuggestions(for: trimmedKey), id: \.self) { action in
                                Text("• \(action)")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, 8)
                    } else {
                        Text("Tap a feeling to see its meaning")
                            .font(.body)
                            .foregroundStyle(AppTheme.colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: emotionRouter.learnEmotions)
                .frame(minHeight: 100, alignment: .topLeading)
            }
        }
    }

    private var emotionInsightsSection: some View {
        LearnSectionCard {
            EmotionInsightsView()
        }
    }

    private func actionSuggestions(for emotion: String) -> [String] {
        let e = emotion.lowercased()

        if ["anxious", "scared", "insecure"].contains(e) {
            return ["Try box breathing for 2 minutes", "Write down what's worrying you", "Focus on what you can control"]
        }
        if ["angry", "frustrated", "mad"].contains(e) {
            return ["Take a short walk", "Step away before reacting", "Write what triggered you"]
        }
        if ["sad", "lonely"].contains(e) {
            return ["Text someone you trust", "Listen to music that matches your mood", "Rest without pressure"]
        }

        return ["Pause and take 3 slow breaths", "Check in with your body", "Name what you need right now"]
    }

    // MARK: Section 4 — Education (three cards)

    private var wheelExplainedCards: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("The Feelings Wheel Explained")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.colors.textPrimary)
                .padding(.horizontal, 4)

            LearnSectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What it is")
                        .font(.headline)
                        .foregroundStyle(AppTheme.colors.textPrimary)
                    Text("A circular map of emotions: broad categories near the center and more specific words toward the edge. It’s a visual way to scan what you might be experiencing.")
                        .font(.body)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LearnSectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Why it matters")
                        .font(.headline)
                        .foregroundStyle(AppTheme.colors.textPrimary)
                    Text("Naming feelings reduces overwhelm. When you can label an emotion, it becomes easier to regulate, communicate, and choose your next step with care.")
                        .font(.body)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LearnSectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How to use it")
                        .font(.headline)
                        .foregroundStyle(AppTheme.colors.textPrimary)
                    Text("Start with whatever wedge feels closest. Then explore outer words until something resonates. There’s no perfect answer—curiosity is the goal.")
                        .font(.body)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Section 5 — Steps

    private var sixStepGuideSection: some View {
        LearnSectionCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("A 6-step path", systemImage: "list.number")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.colors.textPrimary)

                ForEach(Self.guideSteps) { step in
                    StepRowView(
                        number: step.number,
                        title: step.title,
                        description: step.description,
                        systemImage: step.systemImage,
                        emoji: Self.stepEmoji(for: step.number)
                    )
                }
            }
        }
    }

    // MARK: Section 6 — Box breathing

    private var boxBreathingSection: some View {
        LearnSectionCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Feeling Overwhelmed?")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.colors.textPrimary)

                Text("Follow the square: each side is one phase of the breath. Let the rhythm carry you.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                BoxBreathingView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: Section 7 — Breathing education (multiple cards)

    private var breathingEducationCards: some View {
        VStack(alignment: .leading, spacing: 24) {
            LearnSectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What is Box Breathing")
                        .font(.headline)
                        .foregroundStyle(AppTheme.colors.textPrimary)
                    Text("A paced breath pattern with four equal parts: inhale, hold, exhale, hold. It’s simple to remember and works almost anywhere.")
                        .font(.body)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LearnSectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to Practice")
                        .font(.headline)
                        .foregroundStyle(AppTheme.colors.textPrimary)
                    learnBullet("Sit comfortably, spine tall, jaw soft.")
                    learnBullet("Inhale through the nose for four slow counts.")
                    learnBullet("Hold gently for four counts—no tension in the throat.")
                    learnBullet("Exhale for four counts, shoulders dropping slightly.")
                    learnBullet("Hold empty for four counts, then repeat.")
                }
            }

            LearnSectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Benefits")
                        .font(.headline)
                        .foregroundStyle(AppTheme.colors.textPrimary)
                    learnBullet("Helps shift attention away from racing thoughts.")
                    learnBullet("Encourages a longer exhale, which can feel calming.")
                    learnBullet("Builds a portable reset you can use before sleep or stress.")
                }
            }

            LearnSectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("When to Use")
                        .font(.headline)
                        .foregroundStyle(AppTheme.colors.textPrimary)
                    Text("Before a tough conversation, after long screen time, in traffic, or whenever you notice shallow breathing and want to land back in your body.")
                        .font(.body)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func learnBullet(_ text: String) -> some View {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "—"
            : text
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(AppTheme.colors.sage)
                .padding(.top, 7)
            Text(line)
                .font(.subheadline)
                .foregroundStyle(AppTheme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Step model

private struct LearnStepItem: Identifiable {
    let id: Int
    let number: Int
    let title: String
    let description: String
    let systemImage: String

    init(number: Int, title: String, description: String, systemImage: String) {
        self.id = number
        self.number = number
        self.title = title
        self.description = description
        self.systemImage = systemImage
    }
}

// MARK: - Step row

struct StepRowView: View {
    let number: Int
    let title: String
    let description: String
    let systemImage: String
    let emoji: String

    @State private var animate = false

    private var resolvedIcon: String {
        UIImage(systemName: systemImage) != nil ? systemImage : "sparkles"
    }

    private var stepAccent: Color {
        switch number {
        case 1: return .blue
        case 2: return .pink
        case 3: return .purple
        case 4: return .green
        case 5: return .indigo
        case 6: return .orange
        default: return .blue
        }
    }

    var body: some View {
        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Step" : title
        let safeDescription = description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Keep going—small steps add up."
            : description

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.colors.sand.opacity(0.6)))
                Spacer(minLength: 0)
            }

            HStack(spacing: 14) {
                Image(systemName: resolvedIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(stepAccent)
                    .padding(12)
                    .background(Circle().fill(stepAccent.opacity(0.12)))

                Text(emoji)
                    .font(.system(size: 28))
                    .accessibilityHidden(true)
            }

            Text(safeTitle)
                .font(.headline)
                .foregroundStyle(AppTheme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(safeDescription)
                .font(.subheadline)
                .foregroundStyle(AppTheme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(stepAccent.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(stepAccent.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: AppTheme.colors.bark.opacity(0.12), radius: 4, x: 0, y: 2)
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45).delay(Double(number - 1) * 0.05)) {
                animate = true
            }
        }
    }
}

// MARK: - Box breathing (simple Timer + corner positions; stable in ScrollView)

struct BoxBreathingView: View {
    @State private var step = 0
    @State private var slowMode = false
    @State private var loopTimer: Timer?

    private let size: CGFloat = 180
    private let durationFast: Double = 4
    private let durationSlow: Double = 6

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.gray.opacity(0.15))

                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)

                Circle()
                    .fill(Color.green)
                    .frame(width: 16, height: 16)
                    .position(dotPosition)
                    .animation(.linear(duration: currentDuration), value: step)
            }
            .frame(width: size, height: size)

            Text(phaseText)
                .font(.headline)

            Text("Tap to change speed")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 220)
        .contentShape(Rectangle())
        .onAppear {
            startLoop()
        }
        .onDisappear {
            loopTimer?.invalidate()
            loopTimer = nil
        }
        .onTapGesture {
            slowMode.toggle()
            startLoop()
        }
    }

    private var currentDuration: Double {
        slowMode ? durationSlow : durationFast
    }

    private var dotPosition: CGPoint {
        let padding: CGFloat = 20
        let minX = padding
        let maxX = size - padding
        let minY = padding
        let maxY = size - padding

        switch step % 4 {
        case 0: return CGPoint(x: minX, y: minY)
        case 1: return CGPoint(x: maxX, y: minY)
        case 2: return CGPoint(x: maxX, y: maxY)
        default: return CGPoint(x: minX, y: maxY)
        }
    }

    private var phaseText: String {
        switch step % 4 {
        case 0: return "Inhale"
        case 1: return "Hold"
        case 2: return "Exhale"
        default: return "Hold"
        }
    }

    private func startLoop() {
        loopTimer?.invalidate()
        step = 0
        let interval = currentDuration
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            withAnimation {
                step += 1
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        loopTimer = timer
    }
}

// MARK: - Emotion definitions (keys aligned with FeelingWheelView; always returns visible copy)

enum LearnEmotionDefinitionLookup {
    private static let emojiDefinitions: [String: String] = [
        "😊": "Feeling happy and content.",
        "😤": "Feeling frustrated or stressed.",
        "🥰": "Feeling loved or affectionate.",
        "💪": "Feeling strong or motivated.",
        "💭": "Feeling thoughtful or reflective.",
        "💫": "Feeling inspired or magical."
    ]

    private static let wheelMap: [String: String] = {
        var m: [String: String] = [:]
        func add(_ key: String, _ value: String) {
            m[key] = value
            m[key.lowercased()] = value
        }
        add("Joyful", "A bright, uplifted state—open to pleasure, play, or connection.")
        add("Powerful", "Feeling capable, grounded, or ready to take space when it matters.")
        add("Peaceful", "Soft steadiness; your body may feel slower and your mind quieter.")
        add("Sad", "Sadness often follows loss, disappointment, or unmet needs. It can slow you down and draw your attention to what matters.")
        add("Mad", "Mad (anger) is a response to perceived injustice, threat, or frustration. It often signals that something feels unfair or blocked.")
        add("Scared", "Fear is an alarm system. It narrows attention and prepares your body to respond when something feels uncertain or unsafe.")

        let pairs: [(String, String)] = [
            ("excited", "High energy and anticipation—something ahead feels meaningful."),
            ("sensuous", "Alive to touch, taste, or atmosphere; tuned into the body."),
            ("energetic", "Ready to move; restlessness can show up here too."),
            ("cheerful", "Light, friendly positivity—small things feel a bit brighter."),
            ("creative", "Ideas want to flow; problem-solving feels more playful."),
            ("hopeful", "A forward lean: not everything is solved, but something feels possible."),
            ("aware", "Present and noticing—little shifts in room or mood stand out."),
            ("proud", "Recognition of effort or growth; a warm inner nod to yourself."),
            ("respected", "Feeling seen and valued for who you are, not only what you do."),
            ("appreciated", "Gratitude directed at you—your care landed."),
            ("important", "Your presence matters in this moment or context."),
            ("faithful", "Loyalty to people or principles you trust."),
            ("content", "Enough-ness; not striving hard, just okay here."),
            ("thoughtful", "Reflective and inward; piecing meaning together slowly."),
            ("intimate", "Close, tender closeness with someone you trust."),
            ("loving", "Warm care toward yourself or others."),
            ("trusting", "Letting guard soften because safety feels plausible."),
            ("nurturing", "Instinct to care, soothe, or protect."),
            ("lonely", "A painful sense of disconnection—a signal that belonging or closeness feels missing."),
            ("bored", "Under-stimulated; energy looking for a place to go."),
            ("tired", "Body or mind asking for rest, not more pushing."),
            ("depressed", "Depression is more than sadness: it often includes low energy, loss of interest, and feeling stuck. Professional support can help."),
            ("ashamed", "Shame is the feeling that you are fundamentally flawed; it’s painful and common—and it can soften with safe support."),
            ("guilty", "Guilt usually points to a specific behavior that conflicts with your values; it can motivate repair."),
            ("hurt", "Hurt means something mattered and you felt wounded by it—emotionally or socially."),
            ("hostile", "Hostile anger is outward-facing and protective; it can signal boundaries or pain that need attention."),
            ("angry", "Anger is a cue that something feels wrong, blocked, or unfair to you."),
            ("frustrated", "Frustration is tension when progress is blocked or effort doesn’t match the outcome you want."),
            ("selfish", "A harsh label for normal self-protection; worth reframing with curiosity."),
            ("hateful", "Intense aversion; often pain pointed outward—support can help."),
            ("critical", "Hyper-vigilant scanning for what could go wrong."),
            ("confused", "Too many inputs; clarity hasn’t landed yet."),
            ("rejected", "Not chosen or included in a way that stings."),
            ("helpless", "Unsure what would help; motivation may dip."),
            ("submissive", "Going small to stay safe—sometimes adaptive, sometimes costly."),
            ("insecure", "Uncertainty about worth or belonging in this context."),
            ("anxious", "Anxiety is worry about the future paired with bodily tension; it often shows up when your brain predicts threat or uncertainty."),
            ("worried", "Worry is repetitive mental rehearsal of problems—often trying to prepare you, even when it exhausts you."),
            ("nervous", "Nervousness is activation before a challenge; it can sharpen focus or feel uncomfortable in the body."),
            ("anxiety", "Anxiety is worry about the future paired with bodily tension; it often shows up when your brain predicts threat or uncertainty.")
        ]
        for (k, v) in pairs { add(k, v) }
        return m
    }()

    /// Always returns non-empty user-visible text.
    static func definition(for emotion: String) -> String {
        let trimmed = emotion.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Tap a feeling to see its meaning."
        }

        if let d = emojiDefinitions[trimmed], !d.isEmpty { return d }

        if let d = wheelMap.first(where: { $0.key.caseInsensitiveCompare(trimmed) == .orderedSame })?.value, !d.isEmpty {
            return d
        }

        for (primary, secondaries) in FeelingWheelView.emotionMap {
            if let match = secondaries.first(where: {
                $0.caseInsensitiveCompare(trimmed) == .orderedSame
            }) {
                if let d = wheelMap[match.lowercased()], !d.isEmpty {
                    return d
                }
                if let d = wheelMap[match], !d.isEmpty {
                    return d
                }
            }

            if primary.caseInsensitiveCompare(trimmed) == .orderedSame {
                if let d = wheelMap[primary], !d.isEmpty {
                    return d
                }
            }
        }

        let pretty = trimmed.capitalized
        return "You’re exploring “\(pretty)”. Stay curious—notice what it feels like in your body."
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        LearnView()
    }
    .environmentObject(AuthManager(previewLoggedIn: true, previewUser: PreviewSampleData.currentUser))
    .environmentObject(FirestoreManager.shared)
    .environmentObject(EmotionRouter())
    .onAppear {
        FirestoreManager.shared.applyPreviewPosts(
            PreviewSampleData.sampleFeedPosts + [PreviewSampleData.previewUserWrapupPost]
        )
    }
}
#endif
