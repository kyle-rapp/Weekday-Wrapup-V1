import SwiftUI
import UIKit

/// FILE: Views/Grow/GrowView.swift
/// Personal emotional insights dashboard: calendar, patterns, lightweight insights.

struct GrowView: View {
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    @StateObject private var viewModel = GrowViewModel()
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var outdoorSuggestions = OutdoorSuggestionsManager()
    @Namespace private var calendarNamespace

    @State private var showPreferencesOnboarding = false
    @State private var recommendationFeedback: [UUID: Bool] = [:]
    @State private var recommendationFeedbackSubmitting: Set<UUID> = []
    @State private var safetyCardDismissed = false
    @State private var therapyResourcesDismissed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                calendarSection

                dailyInsightCard

                helpfulTagInsightCard

                patternsSection

                outdoorContextSection

                if showGrowSafetyPanel {
                    EmotionalSafetySupportCard(resources: growSafetyResources) {
                        safetyCardDismissed = true
                    }
                }

                if !therapyResourcesDismissed, !growTherapyResources.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Suggested resources")
                                .font(.headline)
                                .foregroundStyle(AppTheme.colors.textPrimary)
                            Spacer(minLength: 8)
                            Button("Dismiss") { therapyResourcesDismissed = true }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(growTherapyResources) { resource in
                            ResourceCardView(resource: resource)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                recommendationsSection
            }
            .padding()
            .padding(.top, 8)
        }
        .scrollIndicators(.visible)
        .background(AppTheme.colors.secondaryBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.large)
        .task(id: auth.currentUser?.id) {
            await loadRecommendationFeedback()
            await loadUserPreferences()
            await MainActor.run {
                guard viewModel.userPreferences == nil,
                      !PreferencesOnboardingView.hasCompletedPreferencesProfile,
                      !UserDefaults.standard.bool(forKey: PreferencesOnboardingView.autoPromptKey)
                else { return }
                UserDefaults.standard.set(true, forKey: PreferencesOnboardingView.autoPromptKey)
                showPreferencesOnboarding = true
            }
        }
        .onAppear {
            syncEntriesFromFirestore()
            outdoorSuggestions.startIfNeeded()
        }
        .onReceive(firestore.$posts) { _ in
            syncEntriesFromFirestore()
        }
        .onChange(of: auth.currentUser?.id) { _, _ in
            recommendationFeedback = [:]
            recommendationFeedbackSubmitting = []
            safetyCardDismissed = false
            therapyResourcesDismissed = false
            syncEntriesFromFirestore()
        }
        .onChange(of: viewModel.selectedEmotion) { _, _ in
            calendarViewModel.clearSelection()
            refreshRecommendations()
        }
        .onChange(of: outdoorSuggestions.weatherHint) { _, _ in
            refreshRecommendations()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPreferencesOnboarding = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body.weight(.semibold))
                        .accessibilityLabel("Personalize recommendations")
                }
            }
        }
        .sheet(isPresented: $showPreferencesOnboarding) {
            PreferencesOnboardingView()
                .environmentObject(firestore)
                .environmentObject(auth)
                .onDisappear {
                    Task { await loadUserPreferences() }
                }
        }
    }

    private func loadRecommendationFeedback() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run {
                viewModel.updateRecommendationFeedback([])
                refreshRecommendations()
            }
            return
        }
        let rows = await firestore.fetchRecommendationFeedbackSummary(userId: uid)
        await MainActor.run {
            viewModel.updateRecommendationFeedback(rows.map { (title: $0.title, helpful: $0.helpful) })
            refreshRecommendations()
        }
    }

    private var showGrowSafetyPanel: Bool {
        if safetyCardDismissed { return false }
        guard let e = viewModel.entries.sorted(by: { $0.date > $1.date }).first else { return false }
        let emotion = e.firstSelectedEmotionLabel
        let keywords = (e.helpfulTags ?? []).map { $0.lowercased() }
        let extra = e.selectedEmotions.map { $0.lowercased() }.joined(separator: " ")
        return EmotionalSafetySignals.signalsSupport(emotion: emotion, keywords: keywords, extraText: extra)
    }

    private var growSafetyResources: [ResourceRecommendation] {
        guard let e = viewModel.entries.sorted(by: { $0.date > $1.date }).first else { return [] }
        let text = [e.emotionalInsight, e.whoopsText].joined(separator: " ")
        let stress = viewModel.userPreferences?.topStressors ?? []
        return RecommendationResourceEngine.rank(
            postText: text,
            emotionTags: Array(e.selectedEmotions),
            stressors: stress
        )
    }

    private var growTherapyResources: [TherapyResource] {
        guard let e = viewModel.entries.sorted(by: { $0.date > $1.date }).first else { return [] }
        let text = [
            e.emotionalInsight,
            e.whoopsText,
            e.weeklyGoal,
            e.monthlyGoal
        ].joined(separator: " ")
        return TherapyResourceEngine.matchResources(
            text: text,
            emotions: Array(e.selectedEmotions)
        )
    }

    private func syncEntriesFromFirestore() {
        let list = firestore.wrapupHistoryEntries(forUserId: auth.currentUser?.id)
        viewModel.syncEntries(list)
        refreshRecommendations()
    }

    private func refreshRecommendations() {
        viewModel.refreshPersonalizedRecommendations(weather: outdoorSuggestions.weatherHint)
    }

    private func loadUserPreferences() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run {
                viewModel.setUserPreferences(nil)
                refreshRecommendations()
            }
            return
        }
        let prefs = await firestore.fetchUserPreferences(userId: uid)
        await MainActor.run {
            viewModel.setUserPreferences(prefs)
            refreshRecommendations()
        }
    }

    private func submitFeedback(_ rec: Recommendation, helpful: Bool) async {
        guard let uid = auth.currentUser?.id else { return }
        if recommendationFeedbackSubmitting.contains(rec.id) { return }

        let current = recommendationFeedback[rec.id]
        let newValue: Bool? = (current == helpful) ? nil : helpful
        if newValue == current { return }

        await MainActor.run {
            if newValue == nil {
                recommendationFeedback.removeValue(forKey: rec.id)
            } else {
                recommendationFeedback[rec.id] = newValue
            }
            recommendationFeedbackSubmitting.insert(rec.id)
        }

        guard let v = newValue else {
            await MainActor.run { recommendationFeedbackSubmitting.remove(rec.id) }
            return
        }

        do {
            try await firestore.submitRecommendationFeedback(
                userId: uid,
                recommendationId: rec.id.uuidString,
                title: rec.title,
                reason: rec.reason,
                type: rec.type,
                helpful: v
            )
            await loadRecommendationFeedback()
            await MainActor.run { recommendationFeedbackSubmitting.remove(rec.id) }
        } catch {
            print("⚠️ recommendation feedback: \(error.localizedDescription)")
            await MainActor.run {
                if let current {
                    recommendationFeedback[rec.id] = current
                } else {
                    recommendationFeedback.removeValue(forKey: rec.id)
                }
                recommendationFeedbackSubmitting.remove(rec.id)
            }
        }
    }

    // MARK: Calendar (hero)

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                emotionFilterBar

                EmotionCalendarGridView(
                    calendar: calendarViewModel,
                    entries: viewModel.filteredEntries,
                    namespace: calendarNamespace
                )
            }

            calendarDayDetailPanel
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.colors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: AppTheme.colors.bark.opacity(0.08), radius: 14, x: 0, y: 5)
    }

    // MARK: Daily insight

    private var dailyInsightCard: some View {
        InsightCardView(
            title: "Today's Insight",
            bodyText: viewModel.insightText,
            icon: nil,
            backgroundFill: Color.blue.opacity(0.1),
            backgroundOpacity: 1,
            strokeOpacity: 0
        )
    }

    private var helpfulTagInsightCard: some View {
        Group {
            if let line = viewModel.topHelpfulTagLine {
                InsightCardView(
                    title: "What helps you",
                    bodyText: line,
                    icon: "sparkles",
                    backgroundFill: AppTheme.colors.sand,
                    backgroundOpacity: 0.35,
                    strokeOpacity: 0.06
                )
            }
        }
    }

    private var emotionFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                EmotionChipView(title: "All", isSelected: viewModel.selectedEmotion == nil) {
                    viewModel.selectedEmotion = nil
                }
                ForEach(viewModel.topEmotions, id: \.self) { emo in
                    EmotionChipView(title: emo, isSelected: viewModel.selectedEmotion == emo) {
                        viewModel.selectedEmotion = emo
                    }
                }
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calendarDayDetailPanel: some View {
        Group {
            if let date = calendarViewModel.selectedCalendarDate,
               let entry = viewModel.entry(on: date) {
                DayDetailCompact(entry: entry)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: calendarViewModel.selectedCalendarDate?.timeIntervalSince1970 ?? 0)
    }

    // MARK: Patterns

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Patterns")
                .font(.headline)
                .foregroundStyle(AppTheme.colors.textPrimary)

            Text("Most common emotion: \(viewModel.mostCommonEmotion)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.colors.textSecondary)

            Text("Average intensity: \(viewModel.averageIntensity)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Outdoor / weather (on-device)

    private var outdoorContextSection: some View {
        Group {
            if outdoorSuggestions.weatherLine != nil || outdoorSuggestions.nearbyLine != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Around you")
                        .font(.headline)
                        .foregroundStyle(AppTheme.colors.textPrimary)
                    if let w = outdoorSuggestions.weatherLine {
                        Text(w)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let n = outdoorSuggestions.nearbyLine {
                        Text(n)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Recommended for you")
                    .font(.headline)
                    .foregroundStyle(AppTheme.colors.textPrimary)
                Spacer(minLength: 8)
                Button("Personalize") {
                    showPreferencesOnboarding = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.colors.ocean)
            }

            if viewModel.personalizedRecommendations.isEmpty {
                Text(viewModel.recommendationText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(viewModel.personalizedRecommendations) { rec in
                    RecommendationCardView(
                        recommendation: rec,
                        selectedFeedback: recommendationFeedback[rec.id],
                        onStart: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        },
                        onFeedback: { helpful in
                            Task { await submitFeedback(rec, helpful: helpful) }
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GrowView()
            .environmentObject(AuthManager(previewLoggedIn: true))
            .environmentObject(FirestoreManager.shared)
    }
}
#endif
