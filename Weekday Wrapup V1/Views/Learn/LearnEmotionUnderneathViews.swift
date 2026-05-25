import SwiftUI

/// FILE: Views/Learn/LearnEmotionUnderneathViews.swift
/// Dynamic "What might be underneath this?" journey + static pattern diagram + resource link.

// MARK: - Content model

private struct UnderneathStep: Identifiable {
    let id = UUID()
    let heading: String
    let items: [String]
    let systemImage: String
    let tint: Color
}

private enum LearnPrimaryEmotion {
    case mad, scared, sad, joyful, powerful, peaceful, unknown
}

private enum LearnUnderneathContentProvider {
    static func primary(for emotion: String) -> LearnPrimaryEmotion {
        let key = emotion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return .unknown }

        for (primary, secondaries) in FeelingWheelView.emotionMap {
            let p = primary.lowercased()
            if key == p || key.contains(p) { return mapPrimary(primary) }
            if secondaries.contains(where: { $0.lowercased() == key || key.contains($0.lowercased()) }) {
                return mapPrimary(primary)
            }
        }

        if key.contains("angry") || key.contains("mad") || key.contains("frustrat") || key.contains("hostile") {
            return .mad
        }
        if key.contains("scar") || key.contains("anxious") || key.contains("worry") || key.contains("nervous") {
            return .scared
        }
        if key.contains("sad") || key.contains("lonely") || key.contains("depress") || key.contains("guilt") {
            return .sad
        }
        if key.contains("joy") || key.contains("happy") || key.contains("excited") || key.contains("cheer") {
            return .joyful
        }
        if key.contains("power") || key.contains("proud") || key.contains("strong") {
            return .powerful
        }
        if key.contains("peace") || key.contains("calm") || key.contains("content") || key.contains("loving") {
            return .peaceful
        }
        return .unknown
    }

    private static func mapPrimary(_ primary: String) -> LearnPrimaryEmotion {
        switch primary {
        case "Mad": return .mad
        case "Scared": return .scared
        case "Sad": return .sad
        case "Joyful": return .joyful
        case "Powerful": return .powerful
        case "Peaceful": return .peaceful
        default: return .unknown
        }
    }

    static func steps(for emotion: String) -> [UnderneathStep] {
        switch primary(for: emotion) {
        case .mad:
            return [
                UnderneathStep(heading: "You may feel", items: ["Angry", "Disrespected", "Unheard"], systemImage: "flame.fill", tint: Color(red: 0.88, green: 0.62, blue: 0.44)),
                UnderneathStep(heading: "This may make you want to", items: ["Lash out", "Withdraw", "Punch something", "Criticize"], systemImage: "bolt.fill", tint: Color(red: 0.92, green: 0.55, blue: 0.45)),
                UnderneathStep(heading: "What you may really need", items: ["Respect", "Boundaries", "Being heard"], systemImage: "heart.text.square.fill", tint: AppTheme.colors.sage),
                UnderneathStep(heading: "Try instead", items: ["State clearly what you need from others AND yourself."], systemImage: "arrow.turn.up.right", tint: AppTheme.colors.pine)
            ]
        case .scared:
            return [
                UnderneathStep(heading: "You may feel", items: ["Scared", "Overwhelmed", "Unsafe"], systemImage: "cloud.rain.fill", tint: Color(red: 0.91, green: 0.81, blue: 0.72)),
                UnderneathStep(heading: "This may make you want to", items: ["Withdraw", "Numb yourself", "Avoid"], systemImage: "eye.slash.fill", tint: Color(red: 0.78, green: 0.72, blue: 0.86)),
                UnderneathStep(heading: "What you may really need", items: ["Safety", "Clarity", "Stability"], systemImage: "shield.lefthalf.filled", tint: AppTheme.colors.ocean),
                UnderneathStep(heading: "Try instead", items: ["Write a to-do list and begin one small step at a time."], systemImage: "list.bullet.clipboard.fill", tint: AppTheme.colors.pine)
            ]
        case .sad:
            return [
                UnderneathStep(heading: "You may feel", items: ["Sad"], systemImage: "drop.fill", tint: Color(red: 0.63, green: 0.82, blue: 0.92)),
                UnderneathStep(heading: "This may make you want to", items: ["Withdraw", "Isolate"], systemImage: "figure.walk.departure", tint: Color(red: 0.58, green: 0.72, blue: 0.88)),
                UnderneathStep(heading: "What you may need", items: ["Support", "Perspective"], systemImage: "person.2.fill", tint: AppTheme.colors.sage),
                UnderneathStep(heading: "Try", items: ["Write about yourself from the perspective of people who care about you."], systemImage: "pencil.and.outline", tint: AppTheme.colors.pine)
            ]
        case .joyful, .powerful, .peaceful:
            return [
                UnderneathStep(heading: "What helped?", items: ["Notice what was present in your body, environment, or relationships today."], systemImage: "sparkle", tint: AppTheme.colors.moss),
                UnderneathStep(heading: "What need was met?", items: ["Rest, connection, accomplishment, safety, play—name what felt satisfied."], systemImage: "heart.circle.fill", tint: AppTheme.colors.sage),
                UnderneathStep(heading: "How can you recreate this?", items: ["Choose one small, repeatable way to invite this feeling again."], systemImage: "arrow.triangle.2.circlepath", tint: AppTheme.colors.pine)
            ]
        case .unknown:
            return [
                UnderneathStep(heading: "You may feel", items: ["Something important is asking for attention"], systemImage: "questionmark.circle.fill", tint: AppTheme.colors.clay),
                UnderneathStep(heading: "This may make you want to", items: ["Pull away", "Push through", "Numb out"], systemImage: "arrow.left.arrow.right", tint: AppTheme.colors.bark),
                UnderneathStep(heading: "What you may really need", items: ["Understanding", "Rest", "Connection"], systemImage: "heart.fill", tint: AppTheme.colors.sage),
                UnderneathStep(heading: "Try instead", items: ["Name the feeling out loud, then ask: what do I need right now?"], systemImage: "leaf.fill", tint: AppTheme.colors.pine)
            ]
        }
    }

    static func sadAlternatePathway() -> [UnderneathStep] {
        [
            UnderneathStep(heading: "Need", items: ["Connection", "Belonging"], systemImage: "person.2.wave.2.fill", tint: AppTheme.colors.ocean),
            UnderneathStep(heading: "Try", items: ["Call family or friends and schedule time together."], systemImage: "phone.fill", tint: AppTheme.colors.pine)
        ]
    }
}

// MARK: - Dynamic underneath section

struct LearnUnderneathSection: View {
    let emotion: String

    private var steps: [UnderneathStep] {
        LearnUnderneathContentProvider.steps(for: emotion)
    }

    private var showSadAlternate: Bool {
        LearnUnderneathContentProvider.primary(for: emotion) == .sad
    }

    var body: some View {
        LearnSectionCard {
            VStack(alignment: .leading, spacing: 18) {
                Label("🧠 What might be underneath this?", systemImage: "brain.head.profile")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.colors.textPrimary)

                Text("A gentle reflection path—not a diagnosis, just a way to get curious.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                underneathJourney(steps: steps)

                if showSadAlternate {
                    Text("Or you might need something different")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.colors.textSecondary)
                        .padding(.top, 4)

                    underneathJourney(steps: LearnUnderneathContentProvider.sadAlternatePathway())
                }
            }
        }
    }

    @ViewBuilder
    private func underneathJourney(steps: [UnderneathStep]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                UnderneathStepCard(step: step)
                if index < steps.count - 1 {
                    UnderneathFlowArrow()
                }
            }
        }
    }
}

private struct UnderneathStepCard: View {
    let step: UnderneathStep

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: step.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(step.tint)
                    .frame(width: 28, height: 28)
                    .background(step.tint.opacity(0.14))
                    .clipShape(Circle())

                Text(step.heading)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.colors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(step.items, id: \.self) { item in
                    Text(item)
                        .font(.body)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, 38)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(step.tint.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(step.tint.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct UnderneathFlowArrow: View {
    var body: some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(AppTheme.colors.sage.opacity(0.35))
                .frame(width: 2, height: 14)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.colors.sage.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

// MARK: - Resource link

struct LearnFriendshipJournalCard: View {
    private let url = URL(string: "https://butterflyszn.com/products/the-guided-friendship-transformation-journal-digital-edition?srsltid=AfmBOooZJDHTrjnle8-h3Oc66GOP9U4_Cihbj4seRvbQ3muejWMIow0T")!

    var body: some View {
        LearnSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Optional reading", systemImage: "book.closed.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.colors.textSecondary)

                Text("Friendship Transformation Journal")
                    .font(.headline)
                    .foregroundStyle(AppTheme.colors.textPrimary)

                Text("A guided journal for deepening friendships—with prompts, not pressure.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Link(destination: url) {
                    Label("View journal", systemImage: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.colors.ocean)
                }
            }
        }
    }
}
