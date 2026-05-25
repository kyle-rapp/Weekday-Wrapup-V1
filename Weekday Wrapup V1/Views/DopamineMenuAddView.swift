import SwiftUI

struct DopamineMenuAddView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var menu: DopamineMenu
    @State private var manualText = ""
    @State private var selectedCategory: DopamineCategory = .appetizer
    @State private var isSaving = false

    @State private var pendingSuggestion: DopamineMenuSuggestion?
    @State private var showAddChoiceDialog = false
    @State private var showEditAlert = false
    @State private var editedSuggestionTitle = ""

    var onSave: (DopamineMenu) async -> Void

    init(menu: DopamineMenu, onSave: @escaping (DopamineMenu) async -> Void) {
        _menu = State(initialValue: menu)
        self.onSave = onSave
    }

    var body: some View {
        List {
            Section("Manual add") {
                TextField("What boosts your mood?", text: $manualText)
                    .textInputAutocapitalization(.sentences)
                Picker("Category", selection: $selectedCategory) {
                    ForEach(DopamineCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                Button {
                    Task { await saveManualItem() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(isSaving || manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Ideas you might like (tap to add)") {
                ForEach(DopamineSuggestionLibrary.all, id: \.title) { suggestion in
                    suggestionRow(suggestion)
                }
            }
        }
        .navigationTitle("Add to Dopamine Menu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .confirmationDialog("Add suggestion", isPresented: $showAddChoiceDialog, titleVisibility: .visible) {
            Button("Add as is") {
                guard let suggestion = pendingSuggestion else { return }
                Task { await addSuggestionAndPersist(suggestion, customTitle: nil) }
            }
            Button("Edit label before adding") {
                guard let suggestion = pendingSuggestion else { return }
                editedSuggestionTitle = suggestion.title
                showEditAlert = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how you want to add this idea.")
        }
        .alert("Edit suggestion label", isPresented: $showEditAlert) {
            TextField("Label", text: $editedSuggestionTitle)
            Button("Add") {
                guard let suggestion = pendingSuggestion else { return }
                let custom = editedSuggestionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                Task { await addSuggestionAndPersist(suggestion, customTitle: custom.isEmpty ? nil : custom) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Optional: personalize the label before saving.")
        }
    }

    @ViewBuilder
    private func suggestionRow(_ suggestion: DopamineMenuSuggestion) -> some View {
        let metadata = DopamineSuggestionLibrary.metadata(for: suggestion)
        Button {
            pendingSuggestion = suggestion
            showAddChoiceDialog = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Text(suggestion.category.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.primary.opacity(0.07)))
                }
                if let description = suggestion.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if metadata.overstimulationRisk {
                    VStack(alignment: .leading, spacing: 2) {
                        if let warning = metadata.warning {
                            Text(warning)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        if let alternative = metadata.sideAlternative {
                            Text(alternative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func saveManualItem() async {
        let trimmed = manualText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        add(trimmed, to: selectedCategory, menu: &menu)
        await onSave(menu.sanitized())
        manualText = ""
    }

    private func addSuggestionAndPersist(_ suggestion: DopamineMenuSuggestion, customTitle: String?) async {
        let title = (customTitle ?? suggestion.title).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        add(title, to: suggestion.category, menu: &menu)
        await onSave(menu.sanitized())
        pendingSuggestion = nil
    }

    private func add(_ item: String, to category: DopamineCategory, menu: inout DopamineMenu) {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch category {
        case .appetizer:
            menu.appetizers.append(trimmed)
        case .entree:
            menu.mains.append(trimmed)
        case .side:
            menu.sides.append(trimmed)
        case .dessert:
            menu.desserts.append(trimmed)
        case .special:
            menu.specials.append(trimmed)
        }
        menu = menu.sanitized()
    }
}
