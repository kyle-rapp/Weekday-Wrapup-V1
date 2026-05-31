import SwiftUI
import UIKit

/// FILE: Views/Grow/GrowView.swift
/// Personal emotional insights dashboard: calendar, patterns, lightweight insights.

struct GrowView: View {
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var tabRouter: TabRouter

    @StateObject private var viewModel = GrowViewModel()
    @ObservedObject var calendarViewModel: CalendarViewModel
    @StateObject private var outdoorSuggestions = OutdoorSuggestionsManager()
    @Namespace private var calendarNamespace

    @State private var showPreferencesOnboarding = false
    @State private var recommendationFeedback: [UUID: Bool] = [:]
    @State private var recommendationFeedbackSubmitting: Set<UUID> = []
    @State private var shownRecommendationIdsThisSession: Set<String> = []
    @State private var bootstrappedUserId: String?
    @State private var entriesSyncSignature: String = ""
    @State private var safetyCardDismissed = false
    @State private var therapyResourcesDismissed = false
    @State private var showManualEntrySheet = false
    @State private var selectedRecommendationDetail: Recommendation?
    private let dopamineMenuAnchorId = "grow_dopamine_menu_anchor"
    private var eventStream: EmotionalEventStreamService {
        EmotionalEventStreamService(firestore: firestore)
    }

    var body: some View {
        ScrollViewReader { proxy in
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
                    dopamineMenuSection
                }
                .padding()
                .padding(.top, 8)
            }
            .scrollIndicators(.visible)
            .background(AppTheme.colors.secondaryBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.large)
            .task(id: auth.currentUser?.id) {
                await bootstrapGrowIfNeeded()
            }
            .onAppear {
                syncEntriesFromFirestore(reason: "onAppear")
                outdoorSuggestions.startIfNeeded()
            }
            .onReceive(firestore.$posts) { _ in
                syncEntriesFromFirestore(reason: "posts_update")
            }
            .onChange(of: auth.currentUser?.id) { _, _ in
                recommendationFeedback = [:]
                recommendationFeedbackSubmitting = []
                shownRecommendationIdsThisSession = []
                bootstrappedUserId = nil
                entriesSyncSignature = ""
                safetyCardDismissed = false
                therapyResourcesDismissed = false
                syncEntriesFromFirestore(reason: "auth_changed")
            }
            .onChange(of: viewModel.selectedEmotion) { _, _ in
                #if DEBUG
                print("[GROW_STABILITY] selectedEmotion changed to \(viewModel.selectedEmotion ?? "All")")
                #endif
                calendarViewModel.clearSelection()
                refreshRecommendations(reason: "emotion_filter_changed")
            }
            .onChange(of: outdoorSuggestions.weatherHint) { _, _ in
                refreshRecommendations(reason: "weather_changed")
            }
            .onChange(of: viewModel.personalizedRecommendations) { _, _ in
                Task { await recordShownRecommendationsIfNeeded() }
            }
            .onChange(of: tabRouter.focusDopamineMenuInGrow) { _, shouldFocus in
                guard shouldFocus else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(dopamineMenuAnchorId, anchor: .top)
                }
                tabRouter.consumeDopamineMenuFocusRequest()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPreferencesOnboarding = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.body.weight(.semibold))
                            Text("Personalize")
                                .font(.subheadline.weight(.semibold))
                        }
                        .accessibilityLabel("Personalize recommendations")
                    }
                }
            }
            .sheet(isPresented: $showPreferencesOnboarding) {
                PreferencesOnboardingView()
                    .environmentObject(firestore)
                    .environmentObject(auth)
                    .onDisappear {
                        Task {
                            await loadUserPreferences()
                            refreshRecommendations(reason: "preferences_onboarding_closed")
                        }
                    }
            }
            .sheet(isPresented: $showManualEntrySheet) {
                if let date = calendarViewModel.selectedCalendarDate {
                    ManualCalendarEntrySheetView(date: date) { emotion, intensity, note in
                        Task { await saveManualCalendarEntry(date: date, emotion: emotion, intensity: intensity, note: note) }
                    }
                }
            }
            .sheet(item: $selectedRecommendationDetail) { recommendation in
                RecommendationDetailSheetView(
                    recommendation: recommendation,
                    selectedFeedback: recommendationFeedback[recommendation.id],
                    onFeedback: { helpful in
                        Task { await submitFeedback(recommendation, helpful: helpful) }
                    }
                )
            }
            .onChange(of: showPreferencesOnboarding) { _, isShown in
                if isShown {
                    showManualEntrySheet = false
                }
            }
            .onChange(of: showManualEntrySheet) { _, isShown in
                if isShown {
                    showPreferencesOnboarding = false
                }
            }
        }
    }

    private func loadRecommendationFeedback() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run {
                viewModel.updateRecommendationFeedback([])
            }
            return
        }
        let rows = await firestore.fetchRecommendationFeedbackSummary(userId: uid)
        await MainActor.run {
            viewModel.updateRecommendationFeedback(rows.map { (title: $0.title, helpful: $0.helpful) })
        }
    }

    private func loadRecommendationMemory() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run {
                viewModel.updateRecommendationMemory([:])
            }
            return
        }
        let memory = await firestore.fetchRecommendationMemory(userId: uid)
        await MainActor.run {
            viewModel.updateRecommendationMemory(memory)
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
            e.gratitudeText,
            e.whoopsText,
            e.lookForwardTo,
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

    private func syncEntriesFromFirestore(reason: String) {
        let list = firestore.wrapupHistoryEntries(forUserId: auth.currentUser?.id)
        let signature = list
            .sorted { $0.date > $1.date }
            .map { "\($0.id)|\($0.date.timeIntervalSince1970)|\($0.intensity ?? -1)" }
            .joined(separator: ";")
        guard signature != entriesSyncSignature else { return }
        entriesSyncSignature = signature
        #if DEBUG
        print("[GROW_STABILITY] sync entries reason=\(reason) count=\(list.count)")
        #endif
        viewModel.syncEntries(list)
        if let uid = auth.currentUser?.id {
            viewModel.mergeDerivedHabitSignals(userId: uid)
        }
        refreshRecommendations(reason: "entries_synced")
    }

    private func refreshRecommendations(reason: String) {
        #if DEBUG
        print("[GROW_STABILITY] refresh recommendations reason=\(reason)")
        #endif
        viewModel.refreshPersonalizedRecommendations(weather: outdoorSuggestions.weatherHint)
    }

    private func loadUserPreferences() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run {
                viewModel.setUserPreferences(nil)
            }
            return
        }
        let prefs = await firestore.fetchUserPreferences(userId: uid)
        await MainActor.run {
            viewModel.setUserPreferences(prefs)
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

    private func loadAdaptiveProfile() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run { viewModel.updateAdaptiveProfile(nil) }
            return
        }
        let profile = await firestore.fetchAdaptiveProfile(userId: uid)
        await MainActor.run { viewModel.updateAdaptiveProfile(profile) }
    }

    private func bootstrapGrowIfNeeded() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run {
                viewModel.updateRecommendationFeedback([])
                viewModel.updateRecommendationMemory([:])
                viewModel.updateHabitSignals([])
                viewModel.updateAdaptiveProfile(nil)
                viewModel.setUserPreferences(nil)
                bootstrappedUserId = nil
            }
            refreshRecommendations(reason: "bootstrap_no_user")
            return
        }
        if bootstrappedUserId == uid { return }
        #if DEBUG
        print("[GROW_STABILITY] bootstrap grow user=\(uid)")
        #endif
        await MainActor.run { bootstrappedUserId = uid }
        async let feedbackTask: Void = loadRecommendationFeedback()
        async let memoryTask: Void = loadRecommendationMemory()
        async let habitsTask: Void = loadHabitSignals()
        async let adaptiveTask: Void = loadAdaptiveProfile()
        async let prefsTask: Void = loadUserPreferences()
        _ = await (feedbackTask, memoryTask, habitsTask, adaptiveTask, prefsTask)
        refreshRecommendations(reason: "bootstrap_complete")
        await MainActor.run {
            guard viewModel.userPreferences == nil,
                  !PreferencesOnboardingView.hasCompletedPreferencesProfile,
                  !UserDefaults.standard.bool(forKey: PreferencesOnboardingView.autoPromptKey)
            else { return }
            UserDefaults.standard.set(true, forKey: PreferencesOnboardingView.autoPromptKey)
            showPreferencesOnboarding = true
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
            AppLogger.log("[RECOMMENDATION] Sending feedback rec=\(rec.id.uuidString) helpful=\(v)")
            await eventStream.logRecommendationInteraction(
                userId: uid,
                recommendation: rec,
                actionType: v ? .complete : .dismiss,
                source: .growTab,
                didHelp: v,
                emotionBefore: currentEmotionSnapshot,
                emotionAfter: nil,
                metadata: ["surface": "grow_feedback"]
            )
            await loadRecommendationFeedback()
            await loadRecommendationMemory()
            await loadAdaptiveProfile()
            refreshRecommendations(reason: "feedback_submitted")
            await MainActor.run { recommendationFeedbackSubmitting.remove(rec.id) }
        } catch {
            AppLogger.error("Recommendation feedback failed: \(error.localizedDescription)")
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
        let recommendations = viewModel.personalizedRecommendations
        let recIds = recommendations.map { $0.id.uuidString }
        let pending = recIds.filter { !shownRecommendationIdsThisSession.contains($0) }
        guard !pending.isEmpty else { return }

        var wrote = false
        for recId in pending {
            guard let rec = recommendations.first(where: { $0.id.uuidString == recId }) else { continue }
            await eventStream.logRecommendationShown(
                userId: uid,
                recommendation: rec,
                source: .growTab,
                emotionBefore: currentEmotionSnapshot
            )
            await MainActor.run { shownRecommendationIdsThisSession.insert(recId) }
            wrote = true
        }
        if wrote {
            await loadRecommendationMemory()
            await loadAdaptiveProfile()
        }
    }
    private var currentEmotionSnapshot: EmotionSnapshot? {
        guard let latest = viewModel.entries.sorted(by: { $0.date > $1.date }).first else { return nil }
        return EmotionSnapshot(
            emotion: latest.firstSelectedEmotionLabel,
            intensity: Double(latest.intensity ?? 5)
        )
    }

    // MARK: Calendar (hero)

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                emotionFilterBar

                EmotionCalendarGridView(
                    calendar: calendarViewModel,
                    entries: viewModel.entries,
                    selectedEmotion: viewModel.selectedEmotion,
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
        let emotionOptions: [String] = {
            var out: [String] = []
            for emotion in viewModel.topEmotions {
                let exists = out.contains { $0.caseInsensitiveCompare(emotion) == .orderedSame }
                if !exists { out.append(emotion) }
            }
            if let selected = viewModel.selectedEmotion,
               !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !out.contains(where: { $0.caseInsensitiveCompare(selected) == .orderedSame }) {
                out.insert(selected, at: 0)
            }
            return out
        }()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                EmotionChipView(title: "All", isSelected: viewModel.selectedEmotion == nil) {
                    viewModel.selectedEmotion = nil
                }
                ForEach(emotionOptions, id: \.self) { emo in
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
                            selectedRecommendationDetail = rec
                            guard let uid = auth.currentUser?.id else { return }
                            Task {
                                await eventStream.logRecommendationInteraction(
                                    userId: uid,
                                    recommendation: rec,
                                    actionType: .click,
                                    source: .growTab,
                                    didHelp: nil,
                                    emotionBefore: currentEmotionSnapshot,
                                    emotionAfter: nil,
                                    metadata: ["surface": "grow_recommendation_card"]
                                )
                            }
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

    private var dopamineMenuSection: some View {
        DopamineMenuView()
            .id(dopamineMenuAnchorId)
    }

    private func saveManualCalendarEntry(date: Date, emotion: String, intensity: Int, note: String?) async {
        guard let uid = auth.currentUser?.id else { return }
        let rawName = auth.currentUser?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let authorName = rawName.isEmpty ? "Member" : rawName
        let previousEntries = firestore.wrapupHistoryEntries(forUserId: uid)
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
            let stream = EmotionalEventStreamService(firestore: firestore)
            let beforeSnapshot: EmotionSnapshot? = {
                guard let previous = previousEntries.sorted(by: { $0.date > $1.date }).first else { return nil }
                return EmotionSnapshot(
                    emotion: previous.firstSelectedEmotionLabel,
                    intensity: Double(previous.intensity ?? 5)
                )
            }()
            let afterSnapshot = EmotionSnapshot(
                emotion: emotion,
                intensity: Double(max(1, min(10, intensity)))
            )
            await stream.logEmotionCheckIn(
                userId: uid,
                source: .growTab,
                emotionBefore: beforeSnapshot,
                emotionAfter: afterSnapshot,
                tags: [emotion.lowercased()],
                metadata: ["flow": "manual_calendar_entry"]
            )
            syncEntriesFromFirestore(reason: "manual_entry_saved")
        } else {
            print("⚠️ manual calendar entry save failed")
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GrowView(calendarViewModel: CalendarViewModel())
            .environmentObject(AuthManager(previewLoggedIn: true))
            .environmentObject(FirestoreManager.shared)
    }
}
#endif
