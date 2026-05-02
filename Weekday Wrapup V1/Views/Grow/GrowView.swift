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
    @State private var shownRecommendationIdsThisSession: Set<String> = []
    @State private var safetyCardDismissed = false
    @State private var therapyResourcesDismissed = false
    @State private var showManualEntrySheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                calendarSection

                dailyInsightCard

                helpfulTagInsightCard
                habitReinforcementCard

                patternsSection

                outdoorContextSection

                if showGrowSafetyPanel {
                    EmotionalSafetySupportCard(resources: growSafetyResources, showCrisisLine: growShowCrisisLine) {
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
            await loadRecommendationMemory()
            await loadHabitSignals()
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
            shownRecommendationIdsThisSession = []
            safetyCardDismissed = false
            therapyResourcesDismissed = false
            syncEntriesFromFirestore()
            Task { await loadHabitSignals() }
        }
        .onChange(of: viewModel.selectedEmotion) { _, _ in
            calendarViewModel.clearSelection()
            refreshRecommendations()
        }
        .onChange(of: outdoorSuggestions.weatherHint) { _, _ in
            refreshRecommendations()
        }
        .onChange(of: viewModel.personalizedRecommendations) { _, _ in
            Task { await recordShownRecommendationsIfNeeded() }
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
        .sheet(isPresented: $showManualEntrySheet) {
            if let date = calendarViewModel.selectedCalendarDate {
                ManualCalendarEntrySheetView(date: date) { emotion, intensity, note in
                    Task { await saveManualCalendarEntry(date: date, emotion: emotion, intensity: intensity, note: note) }
                }
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

    private func loadRecommendationMemory() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run {
                viewModel.updateRecommendationMemory([:])
                refreshRecommendations()
            }
            return
        }
        let memory = await firestore.fetchRecommendationMemory(userId: uid)
        await MainActor.run {
            viewModel.updateRecommendationMemory(memory)
            refreshRecommendations()
        }
    }

    private var showGrowSafetyPanel: Bool {
        if safetyCardDismissed { return false }
        guard let e = viewModel.entries.sorted(by: { $0.date > $1.date }).first else { return false }
        let emotion = e.firstSelectedEmotionLabel
        let keywords = (e.helpfulTags ?? []).map { $0.lowercased() }
        let extra = e.selectedEmotions.map { $0.lowercased() }.joined(separator: " ")
        let crisisText = [e.emotionalInsight, e.whoopsText, e.whatHelped ?? ""].joined(separator: " ")
        return EmotionalSafetySignals.signalsSupport(emotion: emotion, keywords: keywords, extraText: extra)
            || EmotionalSafetySignals.containsCrisisLanguage(crisisText)
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

    private var growShowCrisisLine: Bool {
        guard let e = viewModel.entries.sorted(by: { $0.date > $1.date }).first else { return false }
        let text = [e.emotionalInsight, e.whoopsText, e.whatHelped ?? ""].joined(separator: " ")
        return EmotionalSafetySignals.containsCrisisLanguage(text)
    }

    private func syncEntriesFromFirestore() {
        let list = firestore.wrapupHistoryEntries(forUserId: auth.currentUser?.id)
        viewModel.syncEntries(list)
        if let uid = auth.currentUser?.id {
            viewModel.mergeDerivedHabitSignals(userId: uid)
        }
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

    private func loadHabitSignals() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run { viewModel.updateHabitSignals([]) }
            return
        }
        let fetched = await firestore.fetchHabitSignals(userId: uid)
        let derived = HabitReinforcementEngine.deriveSignals(from: viewModel.entries, userId: uid)
        let merged = Array(Set(fetched + derived)).sorted { $0.createdAt > $1.createdAt }
        await MainActor.run { viewModel.updateHabitSignals(merged) }
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
            if v {
                try await firestore.recordRecommendationAccepted(userId: uid, recommendationId: rec.id.uuidString)
            } else {
                try await firestore.recordRecommendationDismissed(userId: uid, recommendationId: rec.id.uuidString)
            }
            await loadRecommendationFeedback()
            await loadRecommendationMemory()
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

    private func recordShownRecommendationsIfNeeded() async {
        guard let uid = auth.currentUser?.id else { return }
        let recIds = viewModel.personalizedRecommendations.map { $0.id.uuidString }
        let pending = recIds.filter { !shownRecommendationIdsThisSession.contains($0) }
        guard !pending.isEmpty else { return }

        var wrote = false
        for recId in pending {
            do {
                try await firestore.recordRecommendationShown(userId: uid, recommendationId: recId)
                await MainActor.run { shownRecommendationIdsThisSession.insert(recId) }
                wrote = true
            } catch {
                print("⚠️ recommendation shown memory: \(error.localizedDescription)")
            }
        }
        if wrote {
            await loadRecommendationMemory()
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

    private var habitReinforcementCard: some View {
        Group {
            if let headline = viewModel.topHabitInsightLine {
                InsightCardView(
                    title: "What's helping you most",
                    bodyText: [headline, viewModel.topHabitImprovementLine].compactMap { $0 }.joined(separator: "\n"),
                    icon: "repeat",
                    backgroundFill: AppTheme.colors.ocean.opacity(0.15),
                    backgroundOpacity: 1,
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
            if let date = calendarViewModel.selectedCalendarDate {
                if let entry = viewModel.entry(on: date) {
                    DayDetailCompact(entry: entry)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    manualEntryPrompt(date: date)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: calendarViewModel.selectedCalendarDate?.timeIntervalSince1970 ?? 0)
    }

    private func manualEntryPrompt(date: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(date, style: .date)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.colors.textPrimary)
            Text("No check-in yet for this day.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.colors.textSecondary)
            Button {
                showManualEntrySheet = true
            } label: {
                Label("Add manual entry", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.colors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
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

    private func saveManualCalendarEntry(date: Date, emotion: String, intensity: Int, note: String?) async {
        guard let uid = auth.currentUser?.id else { return }
        let rawName = auth.currentUser?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let authorName = rawName.isEmpty ? "Member" : rawName
        let week = Calendar.current.component(.weekOfYear, from: date)
        let emoji = ReactionManager.emojiForEmotionLabel(emotion)
        let entry = CheckInData(
            userName: authorName,
            astrologySign: "",
            weekNumber: week,
            weeklyEmoji: emoji,
            checkInImage: nil,
            selectedEmotions: [emotion],
            emotionalInsight: note ?? "",
            whoopsText: "",
            poopsText: "",
            weeklyGoal: "",
            monthlyGoal: "",
            visibility: .private,
            date: date,
            intensity: max(1, min(10, intensity)),
            whatHelped: note,
            manualEntry: true,
            selectedEmotionsOrdered: [emotion]
        )
        let ok = await firestore.createPost(from: entry, authorId: uid, authorName: authorName)
        if ok {
            syncEntriesFromFirestore()
        } else {
            print("⚠️ manual calendar entry save failed")
        }
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
