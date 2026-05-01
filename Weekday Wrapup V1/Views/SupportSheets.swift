import SwiftUI

/// FILE: Views/SupportSheets.swift
/// Support action sheets for profile support card.

struct SupportMessageSheetView: View {
    @Environment(\.dismiss) private var dismiss
    var onSend: (String) -> Void
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Optional message") {
                    TextField("Write something kind…", text: $text, axis: .vertical)
                        .lineLimit(2 ... 5)
                }
            }
            .navigationTitle("Send Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        onSend(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SupportInviteSheetView: View {
    @Environment(\.dismiss) private var dismiss
    var onSend: (String) -> Void
    @State private var custom = ""
    @State private var selected = "Walk"

    private let options = ["Walk", "Coffee", "Workout"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick invite") {
                    Picker("Activity", selection: $selected) {
                        ForEach(options, id: \.self) { o in
                            Text(o).tag(o)
                        }
                    }
                }
                Section("Custom text") {
                    TextField("Optional custom invite", text: $custom)
                }
            }
            .navigationTitle("Send Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        let c = custom.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSend(c.isEmpty ? selected : c)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SupportGiftSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let links: [String]
    var onSend: (String) -> Void

    var body: some View {
        NavigationStack {
            List(validLinks, id: \.self) { link in
                Button {
                    onSend(link)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(URL(string: link)?.host ?? "Wishlist item")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(link)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Send Gift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .overlay {
                if validLinks.isEmpty {
                    ContentUnavailableView(
                        "No wishlist items",
                        systemImage: "gift",
                        description: Text("This person hasn’t added wishlist links yet.")
                    )
                }
            }
        }
    }

    private var validLinks: [String] {
        links
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && URL(string: $0) != nil }
    }
}

