import SwiftUI

/// FILE: Views/Components/EmotionalSafetySupportCard.swift
/// Calm, non-clinical support surfaced after vulnerable check-ins.

struct EmotionalSafetySupportCard: View {
    let resources: [ResourceRecommendation]
    var showCrisisLine: Bool = false
    var onDismiss: () -> Void

    @State private var showReachOutTips = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: "hands.sparkles.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.colors.ocean)
                VStack(alignment: .leading, spacing: 6) {
                    Text("You don’t have to go through this alone")
                        .font(.headline)
                        .foregroundStyle(AppTheme.colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("It’s okay to keep things gentle. Small steps and real connection often help more than pushing through.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }

            VStack(alignment: .leading, spacing: 10) {
                if showCrisisLine {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Call or text 988 (US Suicide & Crisis Lifeline)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                        if let crisisURL = URL(string: "tel:988") {
                            Link("Call 988 now", destination: crisisURL)
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.08)))
                }

                Button {
                    showReachOutTips = true
                } label: {
                    Label("Reach out to someone", systemImage: "message.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.colors.pine)

                if !resources.isEmpty {
                    Menu {
                        ForEach(resources.prefix(4)) { rec in
                            if let url = URL(string: rec.url),
                               let scheme = url.scheme?.lowercased(),
                               scheme == "http" || scheme == "https" {
                                Link(rec.title, destination: url)
                            }
                        }
                    } label: {
                        Label("View helpful resources", systemImage: "book.pages")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.colors.mist.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.colors.ocean.opacity(0.12), lineWidth: 1)
        )
        .sheet(isPresented: $showReachOutTips) {
            NavigationStack {
                List {
                    Section {
                        Text("Pick someone you feel safe with—a friend, family member, or counselor.")
                        Text("You can start small: “I’m having a rough stretch and wanted someone to know.”")
                        Text("It’s brave to ask for company, even when it feels awkward.")
                    } footer: {
                        Text("If you might hurt yourself or need immediate help, contact local emergency services or a trusted crisis line in your area.")
                            .font(.caption)
                    }
                }
                .navigationTitle("Reaching out")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showReachOutTips = false }
                    }
                }
            }
        }
    }
}
