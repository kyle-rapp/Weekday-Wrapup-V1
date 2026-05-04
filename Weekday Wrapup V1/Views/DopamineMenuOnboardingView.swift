import SwiftUI

struct DopamineMenuOnboardingView: View {
    var onComplete: (DopamineMenu) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 0
    @State private var menu = DopamineMenu()
    @State private var draft = ""

    private let totalSteps = 7

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
                            dismiss()
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
                title: "Quick Boost",
                description: "Quick boosts that give you energy without pulling you in.",
                examples: ["One favorite song", "1 minute movement", "Quick stretch", "Tea or coffee", "Hug a pet"],
                prompt: "What are 3 quick things that usually make you feel a little better?",
                items: $menu.appetizers,
                placeholder: "e.g. 1 min jumping jacks"
            )
        case 1:
            categoryStep(
                title: "Deep Focus",
                description: "Activities that fully engage you and leave you feeling good after.",
                examples: ["Walk", "Journaling", "Cooking", "Creative hobby", "Exercise"],
                prompt: "What makes you feel alive or fulfilled?",
                items: $menu.mains,
                placeholder: "e.g. journaling"
            )
        case 2:
            categoryStep(
                title: "While Doing Something Else",
                description: "Things that make boring tasks easier or more enjoyable.",
                examples: ["Playlist while cleaning", "Podcast", "Timer challenge", "Body doubling"],
                prompt: "What helps you get through tasks you normally avoid?",
                items: $menu.sides,
                placeholder: "e.g. podcast while cleaning"
            )
        case 3:
            categoryStep(
                title: "Easy to Overdo",
                description: "Easy dopamine - good in moderation, but easy to overdo.",
                examples: ["Social media scroll", "TV", "Games"],
                prompt: "What do you tend to overdo when you're avoiding things?",
                items: $menu.desserts,
                placeholder: "e.g. scrolling TikTok"
            )
        case 4:
            categoryStep(
                title: "Plan Ahead",
                description: "Rare, meaningful experiences that take planning.",
                examples: ["Concert", "Trip", "Nice dinner", "Event with friends"],
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
        examples: [String],
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
            Text("Examples: \(examples.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
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
            compactList(title: "Quick Boost", items: $menu.appetizers)
            compactList(title: "Deep Focus", items: $menu.mains)
            compactList(title: "While Doing Something Else", items: $menu.sides)
            compactList(title: "Easy to Overdo", items: $menu.desserts)
            compactList(title: "Plan Ahead", items: $menu.specials)
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
                    items.wrappedValue.append(trimmed)
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
}
