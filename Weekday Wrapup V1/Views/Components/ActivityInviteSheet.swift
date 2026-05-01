import SwiftUI

/// FILE: Views/Components/ActivityInviteSheet.swift
/// Low-pressure invite copy — share via the system sheet (no in-app purchases).

private struct SharePayload: Identifiable {
    let id = UUID()
    let text: String
}

struct ActivityInviteSheet: View {
    @Environment(\.dismiss) private var dismiss

    let recipientName: String
    let recipientUserId: String

    @State private var showLimitAlert = false
    @State private var sharePayload: SharePayload?

    var body: some View {
        NavigationStack {
            List(ActivityInviteKind.allCases, id: \.self) { kind in
                Button {
                    guard InviteRateLimiter.canSendInvite() else {
                        showLimitAlert = true
                        return
                    }
                    InviteRateLimiter.recordInviteSent()
                    sharePayload = SharePayload(text: kind.message(to: recipientName))
                } label: {
                    Label(kind.title, systemImage: kind.icon)
                }
            }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Invite limit", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You’ve reached today’s gentle limit on invites. Try again tomorrow.")
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: [payload.text])
            }
        }
    }
}

enum ActivityInviteKind: String, CaseIterable {
    case walk
    case coffee
    case hang

    var title: String {
        switch self {
        case .walk: return "Invite to walk"
        case .coffee: return "Invite to coffee"
        case .hang: return "Invite to hang"
        }
    }

    var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .coffee: return "cup.and.saucer.fill"
        case .hang: return "person.2.fill"
        }
    }

    func message(to name: String) -> String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = n.isEmpty ? "you" : n
        switch self {
        case .walk:
            return "Hey \(who) — want to go for a low-key walk sometime soon? No pressure either way."
        case .coffee:
            return "Hey \(who) — I’d love to grab coffee if you’re up for it. Totally fine if now isn’t a good time."
        case .hang:
            return "Hey \(who) — want to hang when things calm down? I’m thinking something easy and low-pressure."
        }
    }
}
