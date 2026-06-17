import SwiftUI

enum ReportReason: String, CaseIterable, Identifiable {
    case harassment = "harassment or bullying"
    case selfHarm = "self-harm concern"
    case misinformation = "misinformation"
    case hate = "hate or abuse"
    case spam = "spam"
    case other = "other"

    var id: String { rawValue }
}

struct ReportTarget {
    var reportedUserId: String?
    var reportedPostId: String?
    var reportedCommentId: String?
}

struct ReportSheetView: View {
    let title: String
    let target: ReportTarget
    let onSubmitted: () -> Void

    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var firestore: FirestoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var reason: ReportReason = .harassment
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Reason", selection: $reason) {
                        ForEach(ReportReason.allCases) { reason in
                            Text(reason.rawValue.capitalized).tag(reason)
                        }
                    }
                }

                Section("Details (optional)") {
                    TextEditor(text: $details)
                        .frame(minHeight: 100)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.colors.error)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Sending..." : "Submit") {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private func submit() async {
        guard let reporterId = auth.currentUser?.id else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await firestore.submitReport(
                reporterUserId: reporterId,
                target: target,
                reason: reason.rawValue,
                details: details
            )
            onSubmitted()
            dismiss()
        } catch {
            errorMessage = "We couldn't send this report right now. Please try again."
        }
    }
}

struct CommunityGuidelinesView: View {
    private let rows: [(String, String)] = [
        ("Be supportive", "Share encouragement and care. Assume good intent when possible."),
        ("No harassment", "Bullying, threats, intimidation, and targeted cruelty are not allowed."),
        ("No hate", "Do not attack people based on identity, background, or lived experience."),
        ("No medical misinformation", "Do not present guesses, supplements, or treatments as medical advice."),
        ("No crisis coaching", "Unless qualified, do not coach people through emergencies or self-harm risk."),
        ("Report concerning content", "Use Report when something feels unsafe, abusive, or misleading."),
        ("Not emergency support", "If someone may be in immediate danger, contact local emergency services or a crisis hotline.")
    ]

    var body: some View {
        List {
            Section {
                Text("SO: Share Openly is for warm reflection and peer support. It is not a replacement for professional or emergency care.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Guidelines") {
                ForEach(rows, id: \.0) { title, detail in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.body.weight(.semibold))
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Community Guidelines")
        .navigationBarTitleDisplayMode(.inline)
    }
}
