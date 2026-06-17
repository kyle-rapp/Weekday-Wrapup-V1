import SwiftUI

/// FILE: Views/DailyCheckInRecommendationsSheet.swift
/// Shown after a successful Share → Feed post.
/// Negative emotions: one low-effort grounding suggestion.
/// Positive emotions (intensity ≥ 5): reflection + Dopamine Menu nudge.

struct DailyRecommendationsPresentation: Identifiable, Equatable {
    let id = UUID()
    let bundle: DailyRecommendationBundle

    static func == (lhs: DailyRecommendationsPresentation, rhs: DailyRecommendationsPresentation) -> Bool {
        lhs.id == rhs.id
    }
}

struct DailyCheckInRecommendationsSheet: View {
    let bundle: DailyRecommendationBundle
    var onDismiss: () -> Void

    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var copingFeedback: Bool?
    @State private var safetyDismissed = false
    @State private var therapyResourcesDismissed = false
    @State private var whatHelpedText = ""
    @State private var addedToDopamineMenu = false
    @State private var isSavingPositiveReflection = false

    private var emotionPolarity: EmotionPolarity {
        DailyCheckInEngine.polarity(for: bundle.checkInEmotion)
    }

    private var isPositiveEmotion: Bool { emotionPolarity == .positive }

    private var needsSafetyPanel: Bool {
        EmotionalSafetySignals.signalsSupport(
            emotion: bundle.checkInEmotion,
            keywords: bundle.analysis.keywords,
            extraText: bundle.analysis.emotionalState
        )
        || EmotionalSafetySignals.containsCrisisLanguage(bundle.sourceText)
    }

    private var safetyResources: [ResourceRecommendation] {
        RecommendationResourceEngine.rank(
            postText: bundle.immediate.reason,
            emotionTags: [bundle.checkInEmotion],
            stressors: []
        )
    }

    private var matchedTherapyResources: [TherapyResource] {
        let blob = [
            bundle.sourceText,
            bundle.analysis.keywords.joined(separator: " "),
            bundle.immediate.reason
        ].joined(separator: " ")
        return TherapyResourceEngine.matchResources(
            text: blob,
            emotions: [bundle.checkInEmotion] + bundle.analysis.keywords
        )
    }

    private var contextualResources: [ContextualCheckInResource] {
        CheckInContextualResources.contextualResources(
            emotion: bundle.checkInEmotion,
            sourceText: bundle.sourceText
        )
    }

    private var showCrisisLine: Bool {
        let text = [bundle.sourceText, bundle.analysis.emotionalState,
                    bundle.analysis.keywords.joined(separator: " ")].joined(separator: " ")
        return EmotionalSafetySignals.containsCrisisLanguage(text)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isPositiveEmotion {
                        positiveContent
                    } else {
                        negativeContent
                    }
                }
                .padding(20)
            }
            .background(AppTheme.colors.secondaryBackground.ignoresSafeArea())
            .navigationTitle(isPositiveEmotion ? "Reflect on today" : "A gentle nudge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task { await closeSheet() }
                    }
                        .font(.body.weight(.semibold))
                }
            }
        }
    }

    // MARK: - Negative Emotion Content

    private var negativeContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Something that might help right now")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("One small thing. No pressure at all.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
            }

            if needsSafetyPanel && !safetyDismissed {
                EmotionalSafetySupportCard(
                    resources: safetyResources,
                    showCrisisLine: showCrisisLine
                ) {
                    safetyDismissed = true
                }
            }

            copingCard

            if !contextualResources.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("You might also appreciate")
                        .font(.headline)
                        .foregroundStyle(AppTheme.colors.textPrimary)
                    ForEach(contextualResources) { resource in
                        ContextualResourceCardView(resource: resource)
                    }
                }
            }

            if !therapyResourcesDismissed, !matchedTherapyResources.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Helpful resources")
                            .font(.headline)
                        Spacer(minLength: 8)
                        Button("Dismiss") {
                            therapyResourcesDismissed = true
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    ForEach(matchedTherapyResources) { resource in
                        ResourceCardView(resource: resource)
                    }
                }
            }
        }
    }

    private var copingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(bundle.immediate.title)
                .font(.headline)
                .foregroundStyle(AppTheme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(bundle.immediate.reason)
                .font(.subheadline)
                .foregroundStyle(AppTheme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    copingFeedback = true
                } label: {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.title3)
                        .foregroundStyle(copingFeedback == true ? Color.green : Color.gray)
                        .scaleEffect(copingFeedback == true ? 1.2 : 1.0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("This helped")

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    copingFeedback = false
                } label: {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.title3)
                        .foregroundStyle(copingFeedback == false ? Color.red : Color.gray)
                        .scaleEffect(copingFeedback == false ? 1.2 : 1.0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Not for me")
            }
            .animation(.easeInOut, value: copingFeedback)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.colors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Positive Emotion Content

    private var positiveContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What helped you feel this way today?")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Capturing what works helps you come back to it on harder days.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            reflectionInputCard

            if !contextualResources.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Worth keeping nearby")
                        .font(.headline)
                        .foregroundStyle(AppTheme.colors.textPrimary)
                    ForEach(contextualResources) { resource in
                        ContextualResourceCardView(resource: resource)
                    }
                }
            }

            dopamineMenuPromptCard
        }
    }

    private var reflectionInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Jot it down (optional)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.colors.textPrimary)

            TextField(
                "e.g. a good walk, sunlight, a real conversation…",
                text: $whatHelpedText,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(2...4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.colors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var dopamineMenuPromptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Add to your Dopamine Menu", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(AppTheme.colors.textPrimary)

            Text("You can add this in your Dopamine Menu in the Grow tab.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if addedToDopamineMenu {
                Label("Opening Grow tab…", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.top, 4)
            } else {
                Button {
                    Task { await openDopamineMenu() }
                } label: {
                    Text("Open Dopamine Menu")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.colors.ocean.opacity(0.12))
                        .foregroundStyle(AppTheme.colors.ocean)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSavingPositiveReflection)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.colors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .animation(.easeInOut, value: addedToDopamineMenu)
    }

    private func closeSheet() async {
        await savePositiveReflectionIfNeeded()
        await MainActor.run {
            onDismiss()
        }
    }

    private func openDopamineMenu() async {
        let hadReflectionText = !whatHelpedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        await savePositiveReflectionIfNeeded()
        await MainActor.run {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            addedToDopamineMenu = true
            #if DEBUG
            print("[POST_POPUP_DOPAMINE_NAV] buttonTapped=true savedReflection=\(hadReflectionText) dismissedSheet=true switchedToGrow=false openedMenu=false")
            #endif
            onDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                tabRouter.openDopamineMenuInGrow()
                #if DEBUG
                print("[POST_POPUP_DOPAMINE_NAV] buttonTapped=true savedReflection=\(hadReflectionText) dismissedSheet=true switchedToGrow=true openedMenu=true")
                #endif
            }
        }
    }

    private func savePositiveReflectionIfNeeded() async {
        guard isPositiveEmotion else { return }
        let trimmed = whatHelpedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isSavingPositiveReflection else { return }
        guard let uid = auth.currentUser?.id else { return }

        await MainActor.run {
            isSavingPositiveReflection = true
        }
        defer {
            Task { @MainActor in
                isSavingPositiveReflection = false
            }
        }

        let tags = EmotionAnalyticsService.extractHelpfulTags(from: trimmed)
        do {
            try await firestore.savePositiveReflection(
                userId: uid,
                emotion: bundle.checkInEmotion,
                text: trimmed,
                tags: tags
            )
            let stream = EmotionalEventStreamService(firestore: firestore)
            let before = EmotionSnapshot(
                emotion: bundle.checkInEmotion,
                intensity: Double(bundle.intensity)
            )
            await stream.logEvent(
                EmotionalEvent(
                    eventId: "event_\(Int(Date().timeIntervalSince1970 * 1000))_reflection_\(StableId.make(prefix: "reflection", title: trimmed, category: "positive_reflection"))",
                    userId: uid,
                    timestamp: Date(),
                    eventType: .postInteraction,
                    emotionBefore: before,
                    emotionAfter: nil,
                    actionType: .reflect,
                    itemId: nil,
                    itemTitle: "positive_reflection",
                    source: .checkInPopup,
                    didHelp: nil,
                    intensityChange: nil,
                    tags: tags,
                    metadata: ["flow": "daily_checkin_sheet"]
                )
            )
        } catch {
            AppLogger.error("savePositiveReflectionIfNeeded failed: \(error.localizedDescription)")
        }
    }
}
