import SwiftUI

struct DopamineMenuView: View {
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    @State private var menu = DopamineMenu()
    @State private var isLoading = true
    @State private var showEdit = false
    @State private var showOnboarding = false
    @State private var preferences: UserPreferences?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Dopamine Menu")
                    .font(.headline)
                Spacer()
                if !menu.isEmpty {
                    Button("Edit") { showEdit = true }
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
                categoryCard("Quick Boost", items: menu.appetizers, suggestions: suggestions(for: .appetizers))
                categoryCard("Deep Focus", items: menu.mains, suggestions: suggestions(for: .mains))
                categoryCard("While Doing Something Else", items: menu.sides, suggestions: suggestions(for: .sides))
                categoryCard("Easy to Overdo", items: menu.desserts, suggestions: suggestions(for: .desserts))
                categoryCard("Plan Ahead", items: menu.specials, suggestions: suggestions(for: .specials))

                if !menu.prepNotes.isEmpty || !menu.barriers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if !menu.prepNotes.isEmpty {
                            Text("Prep")
                                .font(.subheadline.weight(.semibold))
                            chipList(menu.prepNotes)
                        }
                        if !menu.barriers.isEmpty {
                            Text("Barriers")
                                .font(.subheadline.weight(.semibold))
                            Text("Make distractions harder to access (e.g. move apps, add friction)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            chipList(menu.barriers)
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
        .sheet(isPresented: $showOnboarding) {
            DopamineMenuOnboardingView { created in
                Task { await saveMenu(created) }
            }
        }
        .task(id: auth.currentUser?.id) {
            await loadMenu()
            await loadPreferences()
        }
    }

    private func categoryCard(_ title: String, items: [String], suggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            if items.isEmpty {
                Text("No items yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                chipList(Array(items.prefix(5)))
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

    private func chipList(_ items: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .lineLimit(2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Capsule().fill(Color.primary.opacity(0.07)))
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
        do {
            try await firestore.saveDopamineMenu(userId: uid, menu: updated)
            await MainActor.run {
                menu = updated.sanitized()
            }
        } catch {
            AppLogger.error("Dopamine menu save failed: \(error.localizedDescription)")
        }
    }

    private func loadPreferences() async {
        guard let uid = auth.currentUser?.id else { return }
        let prefs = await firestore.fetchUserPreferences(userId: uid)
        await MainActor.run { preferences = prefs }
    }

    private enum Category {
        case appetizers, mains, sides, desserts, specials
    }

    private func suggestions(for category: Category) -> [String] {
        var base: [String] = []
        let helperTags = firestore.posts
            .filter { $0.authorId == auth.currentUser?.id }
            .flatMap(\.helpfulTags)

        switch category {
        case .appetizers:
            base = ["Listen to a favorite playlist", "Step outside for 3 minutes", "Drink water and stretch"]
            if preferences?.hasPet == true { base.append("Quick pet cuddle break") }
        case .mains:
            base = ["Go for a short walk", "Write one page in your journal", "Cook a simple meal"]
            if preferences?.journals == true { base.append("10-minute journal sprint") }
        case .sides:
            base = ["Play music while cleaning", "Set a 10-minute timer", "Body-double a task"]
        case .desserts:
            base = ["One short episode", "15-minute social scroll cap", "One casual game round"]
        case .specials:
            base = ["Plan a weekend outing", "Book a concert or event", "Schedule a friend dinner"]
        }

        base.append(contentsOf: helperTags.map { "Repeat: \($0)" })
        var seen = Set<String>()
        return base.filter { seen.insert($0.lowercased()).inserted }
    }
}
