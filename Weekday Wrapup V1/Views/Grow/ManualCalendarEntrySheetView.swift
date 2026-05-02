import SwiftUI

/// FILE: Views/Grow/ManualCalendarEntrySheetView.swift
/// Lightweight manual check-in for empty calendar days.
struct ManualCalendarEntrySheetView: View {
    @Environment(\.dismiss) private var dismiss

    let date: Date
    var onSave: (_ emotion: String, _ intensity: Int, _ note: String?) -> Void

    @State private var emotion = "Sad"
    @State private var intensity = 5.0
    @State private var note = ""

    private let emotionOptions = [
        "Sad", "Angry", "Scared", "Joyful", "Peaceful", "Powerful", "Anxious", "Lonely"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.secondary)
                }
                Section("Emotion") {
                    Picker("Emotion", selection: $emotion) {
                        ForEach(emotionOptions, id: \.self) { item in
                            Text(item).tag(item)
                        }
                    }
                }
                Section("Intensity") {
                    VStack(alignment: .leading, spacing: 8) {
                        Slider(value: $intensity, in: 1...10, step: 1)
                        Text("\(Int(intensity))/10")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Optional note") {
                    TextField("What happened today?", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Manual check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let clean = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(emotion, Int(intensity), clean.isEmpty ? nil : clean)
                        dismiss()
                    }
                }
            }
        }
    }
}
