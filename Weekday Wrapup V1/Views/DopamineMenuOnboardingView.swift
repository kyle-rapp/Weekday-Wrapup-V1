import SwiftUI

struct DopamineMenuOnboardingView: View {
    var onComplete: (DopamineMenu) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 0
    @State private var menu = DopamineMenu()
    @State private var draft = ""

    private let totalSteps = 7

    init(initialMenu: DopamineMenu = DopamineMenu(), onComplete: @escaping (DopamineMenu) -> Void) {
        self.onComplete = onComplete
        _menu = State(initialValue: initialMenu)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProgressView(value: Double(step + 1), total: Double(totalSteps))
                    .tint(AppTheme.colors.ocean)

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                HStack {
                    if step > 0 {
                        Button("Back") { withAnimation(.easeInOut(duration: 0.2)) { step -= 1 } }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    Button(step == totalSteps - 1 ? "Save Menu" : "Next") {
                        if step == totalSteps - 1 {
                            let final = menu.sanitized()
                            onComplete(final)
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .navigationTitle("Build your menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            categoryStep(
                title: "Appetizers",
                description: "Short activities that give a fast mood lift without taking over your day.",
                suggestions: ["favorite song", "stretch for two minutes", "drink water", "step outside", "quick breathing reset"],
                prompt: "What are 3 quick things that usually make you feel a little better?",
                items: $menu.appetizers,
                placeholder: "e.g. 1 min jumping jacks"
            )
        case 1:
            categoryStep(
                title: "Entrées",
                description: "More immersive activities that feel energizing or meaningful.",
                suggestions: ["long walk", "cook something", "journaling", "hobby session", "call a friend"],
                prompt: "What makes you feel alive or fulfilled?",
                items: $menu.mains,
                placeholder: "e.g. journaling"
            )
        case 2:
            categoryStep(
                title: "Sides",
                description: "Supportive activities that enhance other tasks.",
                suggestions: ["podcast while cleaning", "focus playlist", "audiobook", "body doubling", "timer challenge"],
                prompt: "What helps you get through tasks you normally avoid?",
                items: $menu.sides,
                placeholder: "e.g. podcast while cleaning"
            )
        case 3:
            categoryStep(
                title: "Desserts",
                description: "Comfort activities that can become overused if unbalanced.",
                suggestions: ["short TV episode", "social media with timer", "cozy game", "memes", "favorite snack"],
                prompt: "What do you tend to overdo when you're avoiding things?",
                items: $menu.desserts,
                placeholder: "e.g. scrolling TikTok"
            )
        case 4:
            categoryStep(
                title: "Specials",
                description: "Intentional, higher-effort experiences worth planning for.",
                suggestions: ["museum trip", "concert", "dinner with friend", "massage", "planned nature day"],
                prompt: "What are things you look forward to?",
                items: $menu.specials,
                placeholder: "e.g. concert"
            )
        case 5:
            streamlineStep
        default:
            prepBarrierStep
        }
    }

    private func categoryStep(
        title: String,
        description: String,
        suggestions: [String],
        prompt: String,
        items: Binding<[String]>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Text("Tap an idea to add it")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 8)], spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        let alreadyAdded = items.wrappedValue.contains { $0.caseInsensitiveCompare(suggestion) == .orderedSame }
                        Button {
                            addUnique(suggestion, to: items)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                                Text(suggestion)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(alreadyAdded ? AppTheme.colors.sage.opacity(0.16) : AppTheme.colors.sand.opacity(0.25))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(alreadyAdded)
                    }
                }
            }
            Text(prompt)
                .font(.subheadline.weight(.semibold))
            itemEditor(items: items, placeholder: placeholder)
        }
    }

    private var streamlineStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Would you actually do these?")
                .font(.title3.bold())
            Text("Trim each category to 3-6 realistic options.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            compactList(title: "Appetizers", items: $menu.appetizers)
            compactList(title: "Entrées", items: $menu.mains)
            compactList(title: "Sides", items: $menu.sides)
            compactList(title: "Desserts", items: $menu.desserts)
            compactList(title: "Specials", items: $menu.specials)
        }
    }

    private var prepBarrierStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Make it easier to follow through")
                .font(.title3.bold())
            Text("Optional: add setup notes and barriers for habits you want less of.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Prep notes")
                .font(.subheadline.weight(.semibold))
            itemEditor(items: $menu.prepNotes, placeholder: "e.g. keep workout clothes visible")

            Text("Barriers")
                .font(.subheadline.weight(.semibold))
            Text("Make distractions harder to access (e.g. move apps, add friction)")
                .font(.caption)
                .foregroundStyle(.secondary)
            itemEditor(items: $menu.barriers, placeholder: "e.g. move apps off home screen")
        }
    }

    private func compactList(title: String, items: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(items.wrappedValue.enumerated()), id: \.offset) { idx, item in
                HStack {
                    Text(item)
                        .lineLimit(1)
                    Spacer()
                    Button(role: .destructive) {
                        items.wrappedValue.remove(at: idx)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                }
                .font(.footnote)
            }
        }
    }

    private func itemEditor(items: Binding<[String]>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(placeholder, text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    addUnique(trimmed, to: items)
                    draft = ""
                }
                .buttonStyle(.bordered)
            }
            ForEach(Array(items.wrappedValue.enumerated()), id: \.offset) { idx, item in
                HStack {
                    Text(item)
                        .font(.footnote)
                    Spacer()
                    Button(role: .destructive) {
                        items.wrappedValue.remove(at: idx)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func addUnique(_ value: String, to items: Binding<[String]>) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !items.wrappedValue.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        items.wrappedValue.append(trimmed)
    }
}
