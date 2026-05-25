import SwiftUI

struct DopamineMenuEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var menu: DopamineMenu
    @State private var isSaving = false
    var onSave: (DopamineMenu) async -> Void

    init(menu: DopamineMenu, onSave: @escaping (DopamineMenu) async -> Void) {
        _menu = State(initialValue: menu)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Add things that help you feel better — from quick boosts to meaningful activities.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }

                editorSection(
                    "Appetizers",
                    description: "Quick boosts that give a fast mood lift without taking over your day.",
                    items: $menu.appetizers
                )
                editorSection(
                    "Entrées",
                    description: "More immersive activities that feel energizing or meaningful.",
                    items: $menu.mains
                )
                editorSection(
                    "Sides",
                    description: "Supportive activities that enhance other tasks.",
                    items: $menu.sides
                )
                editorSection(
                    "Desserts",
                    description: "Comfort activities that can become overused if unbalanced.",
                    items: $menu.desserts
                )
                editorSection(
                    "Specials",
                    description: "Intentional, higher-effort experiences worth planning for.",
                    items: $menu.specials
                )
                editorSection("Prep notes", description: "", items: $menu.prepNotes)
                editorSection("Barriers", description: "", items: $menu.barriers)
            }
            .navigationTitle("Edit menu")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            await onSave(menu.sanitized())
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func editorSection(_ title: String, description: String, items: Binding<[String]>) -> some View {
        Section(header: VStack(alignment: .leading, spacing: 2) {
            Text(title)
            if !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .padding(.bottom, 2)
            }
        }) {
            ForEach(Array(items.wrappedValue.enumerated()), id: \.offset) { idx, _ in
                TextField(
                    "Item",
                    text: Binding(
                        get: { items.wrappedValue[idx] },
                        set: { items.wrappedValue[idx] = $0 }
                    )
                )
            }
            .onDelete { items.wrappedValue.remove(atOffsets: $0) }

            Button {
                items.wrappedValue.append("")
            } label: {
                Label("Add item", systemImage: "plus.circle")
            }
        }
    }
}
