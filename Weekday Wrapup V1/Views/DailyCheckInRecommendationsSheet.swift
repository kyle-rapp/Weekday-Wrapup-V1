import SwiftUI

/// FILE: Views/DailyCheckInRecommendationsSheet.swift
/// Shown after a successful Share → Feed post with immediate, habit, and resource lanes.

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
    @State private var recommendationVotes: [UUID: Bool] = [:]
    @State private var resourceVote: Bool?
    @State private var safetyDismissed = false
    @State private var therapyResourcesDismissed = false

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
            postText: bundle.immediate.reason + " " + bundle.personalized.reason,
            emotionTags: [bundle.checkInEmotion],
            stressors: []
        )
    }

    private var matchedTherapyResources: [TherapyResource] {
        let blob = [
            bundle.sourceText,
            bundle.analysis.keywords.joined(separator: " "),
            bundle.immediate.reason,
            bundle.personalized.reason
        ].joined(separator: " ")
        return TherapyResourceEngine.matchResources(
            text: blob,
            emotions: [bundle.checkInEmotion] + bundle.analysis.keywords
        )
    }

    private var showCrisisLine: Bool {
        let text = [bundle.sourceText, bundle.analysis.emotionalState, bundle.analysis.keywords.joined(separator: " ")].joined(separator: " ")
        return EmotionalSafetySignals.containsCrisisLanguage(text)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Here’s something that may help right now")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if needsSafetyPanel && !safetyDismissed {
                        EmotionalSafetySupportCard(resources: safetyResources, showCrisisLine: showCrisisLine) {
                            safetyDismissed = true
                        }
                    }

                    analysisStrip

                    RecommendationCardView(
                        recommendation: bundle.immediate,
                        selectedFeedback: recommendationVotes[bundle.immediate.id],
                        onStart: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        },
                        onFeedback: { helpful in
                            Task { await sendRecFeedback(bundle.immediate, helpful: helpful) }
                        }
                    )

                    RecommendationCardView(
                        recommendation: bundle.personalized,
                        selectedFeedback: recommendationVotes[bundle.personalized.id],
                        onStart: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        },
                        onFeedback: { helpful in
                            Task { await sendRecFeedback(bundle.personalized, helpful: helpful) }
                        }
                    )

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

                    resourceBlock
                }
                .padding(20)
            }
            .background(AppTheme.colors.secondaryBackground.ignoresSafeArea())
            .navigationTitle("After your check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                        .font(.body.weight(.semibold))
                }
            }
        }
    }

    private var analysisStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Snapshot")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.colors.textSecondary)
            Text("State: \(bundle.analysis.emotionalState.replacingOccurrences(of: "_", with: " "))")
                .font(.subheadline.weight(.medium))
            if !bundle.analysis.keywords.isEmpty {
                Text("Keywords: \(bundle.analysis.keywords.prefix(5).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.colors.textSecondary)
            }
            Text("Trend: \(bundle.analysis.trend.rawValue)")
                .font(.caption)
                .foregroundStyle(AppTheme.colors.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.colors.mist.opacity(0.35)))
    }

    private var resourceBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Deep resource", systemImage: "link.circle.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.colors.textPrimary)

            if let url = URL(string: bundle.resource.url) {
                Link(destination: url) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(bundle.resource.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(bundle.resource.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Open link")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            ResourceFeedbackRow(
                selectedFeedback: resourceVote,
                onThumb: { helpful in
                    Task { await sendResourceFeedback(helpful: helpful) }
                }
            )
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

    private func sendRecFeedback(_ rec: Recommendation, helpful: Bool) async {
        guard let uid = auth.currentUser?.id else { return }

        let current = recommendationVotes[rec.id]
        let newValue: Bool? = (current == helpful) ? nil : helpful

        await MainActor.run {
            if newValue == nil {
                recommendationVotes.removeValue(forKey: rec.id)
            } else {
                recommendationVotes[rec.id] = newValue
            }
        }

        guard let v = newValue else { return }

        do {
            AppLogger.log("[RECOMMENDATION] Daily sheet feedback rec=\(rec.id.uuidString) helpful=\(v)")
            try await firestore.submitRecommendationFeedback(
                userId: uid,
                recommendationId: rec.id.uuidString,
                title: rec.title,
                reason: rec.reason,
                type: rec.type,
                helpful: v
            )
        } catch {
            AppLogger.error("Daily recommendation feedback failed: \(error.localizedDescription)")
            await MainActor.run {
                if let current {
                    recommendationVotes[rec.id] = current
                } else {
                    recommendationVotes.removeValue(forKey: rec.id)
                }
            }
        }
    }

    private func sendResourceFeedback(helpful: Bool) async {
        guard let uid = auth.currentUser?.id else { return }

        let current = resourceVote
        let newValue: Bool? = (current == helpful) ? nil : helpful

        await MainActor.run {
            resourceVote = newValue
        }

        guard let v = newValue else { return }

        do {
            AppLogger.log("[RECOMMENDATION] Resource feedback resource=\(bundle.resource.id) helpful=\(v)")
            try await firestore.submitRecommendationFeedback(
                userId: uid,
                recommendationId: bundle.resource.id,
                title: bundle.resource.title,
                reason: bundle.resource.summary,
                type: .reflection,
                helpful: v
            )
        } catch {
            AppLogger.error("Resource feedback failed: \(error.localizedDescription)")
            await MainActor.run {
                resourceVote = current
            }
        }
    }
}

// MARK: - Resource thumbs (same UX as cards)

private struct ResourceFeedbackRow: View {
    var selectedFeedback: Bool?
    var onThumb: (Bool) -> Void

    var body: some View {
        let isUp = selectedFeedback == true
        let isDown = selectedFeedback == false

        HStack(spacing: 20) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onThumb(true)
            } label: {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.title3)
                    .foregroundStyle(isUp ? Color.green : Color.gray)
                    .scaleEffect(isUp ? 1.2 : 1.0)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Helpful")

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onThumb(false)
            } label: {
                Image(systemName: "hand.thumbsdown.fill")
                    .font(.title3)
                    .foregroundStyle(isDown ? Color.red : Color.gray)
                    .scaleEffect(isDown ? 1.2 : 1.0)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Not helpful")
        }
        .padding(.top, 4)
        .animation(.easeInOut, value: selectedFeedback)
    }
}
