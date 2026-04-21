import SwiftUI

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

    private static let guideSteps: [LearnStepItem] = [
        LearnStepItem(
            number: 1,
            title: "Identify what you are feeling",
            description: "Pause and name the strongest emotion you notice, even if it’s broad.",
            systemImage: "eye.fill"
        ),
        LearnStepItem(
            number: 2,
            title: "Acknowledge your emotions",
            description: "Let the feeling exist without judging it as good or bad.",
            systemImage: "hand.raised.fill"
        ),
        LearnStepItem(
            number: 3,
            title: "Get curious about the message",
            description: "Ask gently: what might this emotion be trying to tell me?",
            systemImage: "questionmark.circle.fill"
        ),
        LearnStepItem(
            number: 4,
            title: "Build confidence handling it",
            description: "Recall one time you moved through a hard feeling before.",
            systemImage: "shield.lefthalf.filled"
        ),
        LearnStepItem(
            number: 5,
            title: "Know you can handle it long-term",
            description: "Skills grow with practice; discomfort doesn’t mean you’re failing.",
            systemImage: "infinity"
        ),
        LearnStepItem(
            number: 6,
            title: "Take action",
            description: "Pick one small step: a breath, a text, a walk, or a boundary.",
            systemImage: "figure.walk"
        )
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                introSection
                wheelSection
                definitionSection
                wheelExplainedCards
                sixStepGuideSection
                boxBreathingSection
                breathingEducationCards
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
            VStack(alignment: .leading, spacing: 14) {
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
                            get: { emotionRouter.selectedEmotions },
                            set: { emotionRouter.updateSelection($0) }
                        )
                    )
                        .frame(width: 320, height: 320)
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
                    let key = emotionRouter.lastSelectedEmotion
                        ?? emotionRouter.selectedEmotions.sorted().first

                    if let key, !key.isEmpty {
                        Text(key)
                            .font(.title.bold())
                            .foregroundStyle(AppTheme.colors.pine)

                        Text(LearnEmotionDefinitionLookup.definition(for: key))
                            .font(.body)
                            .foregroundStyle(AppTheme.colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
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
                .animation(
                    .easeInOut(duration: 0.28),
                    value: emotionRouter.lastSelectedEmotion
                        ?? emotionRouter.selectedEmotions.sorted().first
                )
                .frame(minHeight: 100, alignment: .topLeading)
            }
        }
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
            VStack(alignment: .leading, spacing: 18) {
                Label("A 6-step path", systemImage: "list.number")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.colors.textPrimary)

                ForEach(Self.guideSteps) { step in
                    StepRowView(
                        number: step.number,
                        title: step.title,
                        description: step.description,
                        systemImage: step.systemImage
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

    var body: some View {
        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Step" : title
        let safeDescription = description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Keep going—small steps add up."
            : description

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.colors.sand.opacity(0.75))
                        .frame(width: 40, height: 40)
                    Text("\(number)")
                        .font(.headline)
                        .foregroundStyle(AppTheme.colors.textPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: systemImage)
                            .foregroundStyle(AppTheme.colors.ocean)
                            .font(.body.weight(.semibold))
                        Text(safeTitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(safeDescription)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.colors.secondaryBackground.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Box breathing (high-contrast, obvious motion)

struct BoxBreathingView: View {
    private let phaseDuration: TimeInterval = 4

    @State private var phaseIndex: Int = 0

    private var phaseLabel: String {
        switch phaseIndex % 4 {
        case 0: return "Inhale"
        case 1: return "Hold"
        case 2: return "Exhale"
        default: return "Hold"
        }
    }

    private var breathScale: CGFloat {
        switch phaseIndex % 4 {
        case 0: return 1.08
        case 1: return 1.08
        case 2: return 0.82
        default: return 0.82
        }
    }

    private var strokeOpacity: Double {
        switch phaseIndex % 4 {
        case 0, 1: return 1.0
        case 2: return 0.55
        default: return 0.55
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.colors.ocean.opacity(0.22))
                    .frame(width: 140, height: 140)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.35), lineWidth: 2)
                    .frame(width: 140, height: 140)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        AppTheme.colors.ocean,
                        lineWidth: 5
                    )
                    .opacity(strokeOpacity)
                    .frame(width: 140, height: 140)
                    .scaleEffect(breathScale)
                    .animation(.easeInOut(duration: phaseDuration), value: phaseIndex)
            }
            .frame(width: 160, height: 160)

            VStack(spacing: 6) {
                Text(phaseLabel)
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.colors.textPrimary)

                Text("Phase \((phaseIndex % 4) + 1) of 4 · 4 seconds each")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.colors.textSecondary)

                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i == (phaseIndex % 4) ? AppTheme.colors.moss : Color.primary.opacity(0.12))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            phaseIndex = 0
        }
        .onReceive(Timer.publish(every: phaseDuration, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                phaseIndex = (phaseIndex + 1) % 4
            }
        }
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
        add("Sad", "Often tied to loss or longing; a signal that something you care about feels out of reach.")
        add("Mad", "Energy that says a boundary was crossed or a need wasn’t met.")
        add("Scared", "Protection mode—narrowed focus and heightened alert to stay safe.")

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
            ("lonely", "Aching for connection that isn’t quite there."),
            ("bored", "Under-stimulated; energy looking for a place to go."),
            ("tired", "Body or mind asking for rest, not more pushing."),
            ("depressed", "Heavy, slowed mood that may need gentle support."),
            ("ashamed", "Fear that a flaw defines you; very human, very workable."),
            ("guilty", "Signal that behavior strayed from your values—repair may help."),
            ("hurt", "An emotional bruise—something mattered and it stung."),
            ("hostile", "Sharp, outward-facing anger; protective but costly if stuck."),
            ("angry", "Clear signal that something feels unfair or blocked."),
            ("frustrated", "Blocked goals—almost there, but friction is high."),
            ("selfish", "A harsh label for normal self-protection; worth reframing with curiosity."),
            ("hateful", "Intense aversion; often pain pointed outward—support can help."),
            ("critical", "Hyper-vigilant scanning for what could go wrong."),
            ("confused", "Too many inputs; clarity hasn’t landed yet."),
            ("rejected", "Not chosen or included in a way that stings."),
            ("helpless", "Unsure what would help; motivation may dip."),
            ("submissive", "Going small to stay safe—sometimes adaptive, sometimes costly."),
            ("insecure", "Uncertainty about worth or belonging in this context.")
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
        if let d = wheelMap[trimmed], !d.isEmpty { return d }
        if let d = wheelMap[trimmed.lowercased()], !d.isEmpty { return d }

        for (primary, secondaries) in FeelingWheelView.emotionMap {
            if primary.caseInsensitiveCompare(trimmed) == .orderedSame {
                if let d = wheelMap[primary], !d.isEmpty { return d }
                break
            }
            if secondaries.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                if let d = wheelMap[trimmed.lowercased()], !d.isEmpty { return d }
                if let match = secondaries.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }),
                   let d = wheelMap[match], !d.isEmpty {
                    return d
                }
                break
            }
        }

        let pretty = trimmed.capitalized
        return "You’re exploring “\(pretty)”. Keep noticing what it feels like in your body—gentle curiosity often helps the meaning unfold."
    }
}

#if DEBUG
#Preview {
    LearnViewPreviewHost()
}

private struct LearnViewPreviewHost: View {
    @StateObject private var emotionRouter = EmotionRouter()

    var body: some View {
        NavigationStack {
            LearnView()
                .environmentObject(emotionRouter)
        }
    }
}
#endif
