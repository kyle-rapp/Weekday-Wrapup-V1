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
                editorSection("Appetizers", items: $menu.appetizers)
                editorSection("Mains", items: $menu.mains)
                editorSection("Sides", items: $menu.sides)
                editorSection("Desserts", items: $menu.desserts)
                editorSection("Specials", items: $menu.specials)
                editorSection("Prep notes", items: $menu.prepNotes)
                editorSection("Barriers", items: $menu.barriers)
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

    private func editorSection(_ title: String, items: Binding<[String]>) -> some View {
        Section(title) {
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
