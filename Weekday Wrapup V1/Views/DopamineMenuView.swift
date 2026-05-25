import SwiftUI

struct DopamineMenuView: View {
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    private let personalizationEngine = EmotionPersonalizationEngine()
    @State private var menu = DopamineMenu()
    @State private var isLoading = true
    @State private var showEdit = false
    @State private var showAdd = false
    @State private var showOnboarding = false
    @State private var preferences: UserPreferences?
    @State private var positiveReflectionTags: [String] = []
    @State private var recentUsedItemKey: String?
    @State private var adaptiveProfile: UserAdaptiveProfile?
    @State private var cachedSuggestions: [Category: [String]] = [:]
    @State private var suggestionSignature: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Dopamine Menu")
                    .font(.headline)
                Spacer()
                Button("Add") {
                    showEdit = false
                    showOnboarding = false
                    showAdd = true
                }
                    .font(.subheadline.weight(.semibold))
                if !menu.isEmpty {
                    Button("Edit") {
                        showAdd = false
                        showOnboarding = false
                        showEdit = true
                    }
                        .font(.subheadline.weight(.semibold))
                }
            }

            Text("When you're stuck, pick something from your menu instead of defaulting.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if menu.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No menu yet. Build one in a few guided steps.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Start onboarding") {
                        showAdd = false
                        showEdit = false
                        showOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.colors.background)
                )
            } else {
                categoryCard(
                    "Appetizers",
                    subtitle: "Quick boosts that give a fast mood lift without taking over your day.",
                    items: menu.appetizers,
                    suggestions: cachedSuggestions[.appetizers] ?? []
                )
                categoryCard(
                    "Entrées",
                    subtitle: "More immersive activities that feel energizing or meaningful.",
                    items: menu.mains,
                    suggestions: cachedSuggestions[.mains] ?? []
                )
                categoryCard(
                    "Sides",
                    subtitle: "Supportive activities that enhance other tasks.",
                    items: menu.sides,
                    suggestions: cachedSuggestions[.sides] ?? []
                )
                categoryCard(
                    "Desserts",
                    subtitle: "Comfort activities that can become overused if unbalanced.",
                    items: menu.desserts,
                    suggestions: cachedSuggestions[.desserts] ?? []
                )
                categoryCard(
                    "Specials",
                    subtitle: "Intentional, higher-effort experiences worth planning for.",
                    items: menu.specials,
                    suggestions: cachedSuggestions[.specials] ?? []
                )

                if !menu.prepNotes.isEmpty || !menu.barriers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if !menu.prepNotes.isEmpty {
                            Text("Prep")
                                .font(.subheadline.weight(.semibold))
                            chipList(menu.prepNotes, categoryTitle: "Prep")
                        }
                        if !menu.barriers.isEmpty {
                            Text("Barriers")
                                .font(.subheadline.weight(.semibold))
                            Text("Make distractions harder to access (e.g. move apps, add friction)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            chipList(menu.barriers, categoryTitle: "Barriers")
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.colors.background)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showEdit) {
            DopamineMenuEditView(menu: menu) { updated in
                await saveMenu(updated)
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                DopamineMenuAddView(menu: menu) { updated in
                    await saveMenu(updated)
                }
            }
        }
        .sheet(isPresented: $showOnboarding) {
            DopamineMenuOnboardingView { created in
                Task { await saveMenu(created) }
            }
        }
        .task(id: auth.currentUser?.id) {
            await loadMenu()
            await loadPreferences()
            await loadPositiveReflectionTags()
            await loadAdaptiveProfile()
            await MainActor.run {
                recomputeSuggestionsIfNeeded(reason: "initial_load")
            }
        }
        .onReceive(firestore.$posts) { _ in
            recomputeSuggestionsIfNeeded(reason: "posts_published")
        }
        .onChange(of: preferences) { _, _ in
            recomputeSuggestionsIfNeeded(reason: "preferences_changed")
        }
        .onChange(of: positiveReflectionTags) { _, _ in
            recomputeSuggestionsIfNeeded(reason: "positive_tags_changed")
        }
        .onChange(of: adaptiveProfile) { _, _ in
            recomputeSuggestionsIfNeeded(reason: "adaptive_profile_changed")
        }
    }

    private func categoryCard(_ title: String, subtitle: String = "", items: [String], suggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if items.isEmpty {
                Text("No items yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                chipList(Array(items.prefix(5)), categoryTitle: title)
            }

            if !suggestions.isEmpty {
                Text("Suggested: \(suggestions.prefix(2).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.colors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private func chipList(_ items: [String], categoryTitle: String) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    Task { await logDopamineItemUsed(item, categoryTitle: categoryTitle) }
                } label: {
                    Text(item)
                        .font(.caption)
                        .lineLimit(2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Capsule().fill(recentUsedItemKey == "\(categoryTitle)|\(item.lowercased())" ? Color.green.opacity(0.15) : Color.primary.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadMenu() async {
        guard let uid = auth.currentUser?.id else { return }
        isLoading = true
        let fetched = await firestore.fetchDopamineMenu(userId: uid)
        await MainActor.run {
            menu = fetched ?? DopamineMenu()
            isLoading = false
        }
    }

    private func saveMenu(_ updated: DopamineMenu) async {
        guard let uid = auth.currentUser?.id else { return }
        let previous = menu.sanitized()
        do {
            try await firestore.saveDopamineMenu(userId: uid, menu: updated)
            await MainActor.run {
                menu = updated.sanitized()
            }
            await logDopamineMenuDiffEvents(userId: uid, from: previous, to: updated.sanitized())
        } catch {
            AppLogger.error("Dopamine menu save failed: \(error.localizedDescription)")
        }
    }

    private func loadPreferences() async {
        guard let uid = auth.currentUser?.id else { return }
        let prefs = await firestore.fetchUserPreferences(userId: uid)
        await MainActor.run { preferences = prefs }
    }

    private func loadPositiveReflectionTags() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run { positiveReflectionTags = [] }
            return
        }
        let tags = await firestore.fetchPositiveReflectionTags(userId: uid)
        await MainActor.run { positiveReflectionTags = tags }
    }

    private func loadAdaptiveProfile() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run { adaptiveProfile = nil }
            return
        }
        let profile = await firestore.fetchAdaptiveProfile(userId: uid)
        await MainActor.run { adaptiveProfile = profile }
    }

    private enum Category: CaseIterable {
        case appetizers, mains, sides, desserts, specials
    }

    private func suggestions(for category: Category, ranked: [Recommendation], combinedHelpfulTags: [String]) -> [String] {
        let rankedTitles = ranked.filter { belongsToCategory($0, category: category) }.map(\.title)

        var base = rankedTitles

        switch category {
        case .appetizers:
            base += ["Listen to a favorite playlist", "Step outside for 3 minutes", "Drink water and stretch"]
            if preferences?.hasPet == true { base.append("Quick pet cuddle break") }
        case .mains:
            base += ["Go for a short walk", "Write one page in your journal", "Cook a simple meal"]
            if preferences?.journals == true { base.append("10-minute journal sprint") }
        case .sides:
            base += ["Play music while cleaning", "Set a 10-minute timer", "Body-double a task"]
        case .desserts:
            base += ["One short episode", "15-minute social scroll cap", "One casual game round"]
        case .specials:
            base += ["Plan a weekend outing", "Book a concert or event", "Schedule a friend dinner"]
        }

        base.append(contentsOf: combinedHelpfulTags.map { "Repeat: \($0)" })
        var seen = Set<String>()
        return base.filter { seen.insert($0.lowercased()).inserted }
    }

    private func combinedHelpfulTags() -> [String] {
        let helperTags = firestore.posts
            .filter { $0.authorId == auth.currentUser?.id }
            .flatMap(\.helpfulTags)
        return Array(Set(helperTags + positiveReflectionTags))
    }

    private func currentSuggestionContext() -> EmotionContext {
        let combinedHelpfulTags = combinedHelpfulTags()
        let history = firestore.wrapupHistoryEntries(forUserId: auth.currentUser?.id)
        let context = EmotionContext.fromHistory(
            history,
            userPreferences: preferences,
            weather: .neutral,
            feedbackRows: [],
            memory: [:],
            habitInsights: [],
            adaptiveProfile: adaptiveProfile
        )
        return EmotionContext(
            emotion: context.emotion,
            intensity: context.intensity,
            journalText: context.journalText,
            helpfulTags: Array(Set(context.helpfulTags + combinedHelpfulTags)),
            userPreferences: context.userPreferences,
            history: context.history,
            weather: context.weather,
            feedbackRows: context.feedbackRows,
            memory: context.memory,
            habitInsights: context.habitInsights,
            stressors: context.stressors,
            adaptiveProfile: adaptiveProfile
        )
    }

    private func suggestionInputSignature() -> String {
        let history = firestore.wrapupHistoryEntries(forUserId: auth.currentUser?.id)
        let historySignature = history
            .sorted { $0.date > $1.date }
            .map { "\($0.id)|\($0.date.timeIntervalSince1970)|\($0.firstSelectedEmotionLabel)|\($0.intensity ?? -1)" }
            .joined(separator: ";")
        let postTagSignature = firestore.posts
            .filter { $0.authorId == auth.currentUser?.id }
            .flatMap(\.helpfulTags)
            .map { $0.lowercased() }
            .sorted()
            .joined(separator: ",")
        let positiveTagSignature = positiveReflectionTags
            .map { $0.lowercased() }
            .sorted()
            .joined(separator: ",")
        return [
            auth.currentUser?.id ?? "none",
            historySignature,
            postTagSignature,
            positiveTagSignature,
            preferences.map { String(describing: $0) } ?? "nil",
            adaptiveProfile.map { String(describing: $0) } ?? "nil"
        ].joined(separator: "|")
    }

    private func recomputeSuggestionsIfNeeded(reason: String) {
        let signature = suggestionInputSignature()
        guard signature != suggestionSignature else { return }
        suggestionSignature = signature
        let context = currentSuggestionContext()
        let ranked = personalizationEngine.getRecommendations(context: context, surface: .dopamineMenu)
        let combinedTags = combinedHelpfulTags()
        #if DEBUG
        print("[GROW_STABILITY] Dopamine suggestions recompute reason=\(reason)")
        #endif
        var next: [Category: [String]] = [:]
        for category in Category.allCases {
            next[category] = suggestions(for: category, ranked: ranked, combinedHelpfulTags: combinedTags)
        }
        cachedSuggestions = next
    }

    private func belongsToCategory(_ recommendation: Recommendation, category: Category) -> Bool {
        let title = recommendation.title.lowercased()
        switch category {
        case .appetizers:
            return recommendation.type == .regulation
                || title.contains("two-minute")
                || title.contains("quick")
                || title.contains("short")
        case .mains:
            return recommendation.type == .action
        case .sides:
            return recommendation.type == .reflection
                || title.contains("journal")
                || title.contains("capture")
        case .desserts:
            return recommendation.type == .connection
                || title.contains("comfort")
        case .specials:
            return title.contains("plan")
                || title.contains("book")
                || title.contains("event")
                || title.contains("resource")
        }
    }

    private func logDopamineMenuDiffEvents(userId: String, from oldMenu: DopamineMenu, to newMenu: DopamineMenu) async {
        let stream = EmotionalEventStreamService(firestore: firestore)
        let oldMap = menuEntries(from: oldMenu)
        let newMap = menuEntries(from: newMenu)

        let oldKeys = Set(oldMap.keys)
        let newKeys = Set(newMap.keys)
        let added = newKeys.subtracting(oldKeys)
        let removed = oldKeys.subtracting(newKeys)

        for key in added {
            guard let entry = newMap[key] else { continue }
            let stable = StableItem.fromDopamine(title: entry.title, category: entry.category)
            await stream.logDopamineMenuAction(
                userId: userId,
                eventType: .dopamineMenuAdded,
                actionType: .add,
                item: stable,
                source: .dopamineMenu,
                metadata: ["surface": "dopamine_menu_save"]
            )
        }
        for key in removed {
            guard let entry = oldMap[key] else { continue }
            let stable = StableItem.fromDopamine(title: entry.title, category: entry.category)
            await stream.logDopamineMenuAction(
                userId: userId,
                eventType: .dopamineMenuRemoved,
                actionType: .remove,
                item: stable,
                source: .dopamineMenu,
                metadata: ["surface": "dopamine_menu_save"]
            )
        }
    }

    private func logDopamineItemUsed(_ item: String, categoryTitle: String) async {
        guard let uid = auth.currentUser?.id else { return }
        let stream = EmotionalEventStreamService(firestore: firestore)
        let stable = StableItem.fromDopamine(title: item, category: categoryTitle)
        await stream.logDopamineMenuAction(
            userId: uid,
            eventType: .dopamineMenuUsed,
            actionType: .complete,
            item: stable,
            source: .dopamineMenu,
            metadata: ["surface": "dopamine_menu_chip_tap"]
        )
        await MainActor.run {
            recentUsedItemKey = "\(categoryTitle)|\(item.lowercased())"
        }
    }

    private func menuEntries(from menu: DopamineMenu) -> [String: (title: String, category: String)] {
        var output: [String: (title: String, category: String)] = [:]
        func add(_ values: [String], category: String) {
            for value in values {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !normalized.isEmpty else { continue }
                output["\(category)|\(normalized)"] = (title: value, category: category)
            }
        }
        add(menu.appetizers, category: "Appetizer")
        add(menu.mains, category: "Entrée")
        add(menu.sides, category: "Side")
        add(menu.desserts, category: "Dessert")
        add(menu.specials, category: "Special")
        return output
    }
}
