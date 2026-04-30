import SwiftUI

/// FILE: Views/GroupSettingsView.swift
/// Owner-only: members, pending invites, and optional history access for new members.

struct GroupSettingsView: View {
    let group: SocialGroup

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    @State private var memberIds: [String]
    @State private var pendingInvites: [String]
    @State private var inviteInput = ""
    @State private var allowHistory: Bool
    @State private var isSaving = false
    @State private var errorText: String?

    init(group: SocialGroup) {
        self.group = group
        _memberIds = State(initialValue: group.memberIds)
        _pendingInvites = State(initialValue: group.invitedContacts ?? [])
        _allowHistory = State(initialValue: group.allowHistoryAccessForNewMembers ?? false)
    }

    private var ownerId: String { group.createdBy }
    private var isOwner: Bool { auth.currentUser?.id == ownerId }

    var body: some View {
        Form {
            Section {
                Text(group.name)
                    .font(.headline)
                if let desc = group.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if isOwner {
                Section {
                    Toggle("New members can see past posts", isOn: $allowHistory)
                } footer: {
                    Text("When on, new members may see older group-scoped posts (Firestore rules must allow this).")
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Invite people")
                            .font(.headline)
                        HStack {
                            TextField("Enter email or phone", text: $inviteInput)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                            Button("Add") {
                                addInvite()
                            }
                            .font(.body.weight(.semibold))
                        }
                        ForEach(pendingInvites, id: \.self) { invite in
                            HStack {
                                Text(invite)
                                Spacer()
                                Button("Remove") {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        pendingInvites.removeAll { $0 == invite }
                                    }
                                }
                                .font(.caption.weight(.semibold))
                            }
                        }
                    }
                } header: {
                    Text("Invites")
                }

                Section {
                    ForEach(memberIds, id: \.self) { uid in
                        HStack {
                            Text(shortUserLabel(uid))
                            Spacer()
                            if uid != ownerId {
                                Button("Remove") {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        memberIds.removeAll { $0 == uid }
                                    }
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                            } else {
                                Text("Owner")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Members")
                }
            } else {
                Section {
                    Text("Only the group owner can change members and settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if isOwner {
                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        Text("Save changes")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isSaving)
                }
            }
        }
        .navigationTitle("Group settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn’t save", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private func shortUserLabel(_ uid: String) -> String {
        if uid == auth.currentUser?.id { return "You" }
        if uid == ownerId { return "Owner · \(String(uid.prefix(8)))…" }
        return String(uid.prefix(10)) + "…"
    }

    private func addInvite() {
        let t = inviteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        guard !pendingInvites.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) else {
            inviteInput = ""
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            pendingInvites.append(t)
            inviteInput = ""
        }
    }

    private func save() async {
        guard let uid = auth.currentUser?.id else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await firestore.updateGroup(
                groupId: group.id,
                memberIds: memberIds,
                invitedContacts: pendingInvites,
                allowHistoryAccessForNewMembers: allowHistory,
                actingUserId: uid
            )
            await MainActor.run { dismiss() }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
