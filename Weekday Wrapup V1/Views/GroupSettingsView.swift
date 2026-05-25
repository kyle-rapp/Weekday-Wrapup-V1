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
    @State private var usernameLookup = ""
    @State private var usernameLookupHint: String?
    @State private var allowHistory: Bool
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var memberIdPendingPastAccess: String?
    @State private var adminVotes: [String: Int] = [:]
    @State private var votedForId: String?

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
                        Text("Email, phone, or exact display name as saved in their profile.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("Email or phone", text: $inviteInput)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                            Button("Add") {
                                addInvite()
                            }
                            .font(.body.weight(.semibold))
                        }
                        HStack {
                            TextField("Username (exact name)", text: $usernameLookup)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                            Button("Find") {
                                Task { await findAndAddMemberByName() }
                            }
                            .font(.body.weight(.semibold))
                        }
                        if let usernameLookupHint {
                            Text(usernameLookupHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                                    Task { await removeMember(uid) }
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

            Section {
                adminVotingSection
            } header: {
                Text("Admin Voting")
            } footer: {
                Text("Members can vote for a group admin. Highest votes earns admin privileges.")
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
        .task { await loadAdminVotes() }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn’t save", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
        .confirmationDialog(
            "Allow access to past messages?",
            isPresented: Binding(
                get: { memberIdPendingPastAccess != nil },
                set: { if !$0 { memberIdPendingPastAccess = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Yes — show past group messages") {
                if let id = memberIdPendingPastAccess {
                    memberIdPendingPastAccess = nil
                    Task { await addMemberWithHistoryChoice(newId: id, canSeePast: true) }
                }
            }
            Button("No — only new messages") {
                if let id = memberIdPendingPastAccess {
                    memberIdPendingPastAccess = nil
                    Task { await addMemberWithHistoryChoice(newId: id, canSeePast: false) }
                }
            }
            Button("Cancel", role: .cancel) {
                memberIdPendingPastAccess = nil
            }
        } message: {
            Text("This applies to this person only. You can still change the group default below.")
        }
    }

    @ViewBuilder
    private var adminVotingSection: some View {
        let candidates = memberIds.filter { $0 != ownerId }
        if candidates.isEmpty {
            Text("No other members to vote for yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ForEach(candidates, id: \.self) { cid in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shortUserLabel(cid))
                            .font(.subheadline)
                        let count = adminVotes[cid] ?? 0
                        Text("\(count) vote\(count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if votedForId == cid {
                        Label("Voted", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Button("Vote") {
                            Task { await castVote(for: cid) }
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .disabled(votedForId != nil)
                    }
                }
            }
        }
    }

    private func loadAdminVotes() async {
        let votes = await firestore.fetchGroupAdminVotes(groupId: group.id)
        let me = auth.currentUser?.id ?? ""
        await MainActor.run {
            adminVotes = votes
            // Restore voted state from local key (session-level memory)
            let key = "voted_admin_\(group.id)"
            votedForId = UserDefaults.standard.string(forKey: key)
        }
    }

    private func castVote(for candidateId: String) async {
        guard let voterId = auth.currentUser?.id else { return }
        do {
            try await firestore.voteForGroupAdmin(groupId: group.id, candidateId: candidateId, voterId: voterId)
            let key = "voted_admin_\(group.id)"
            UserDefaults.standard.set(candidateId, forKey: key)
            await MainActor.run {
                votedForId = candidateId
                adminVotes[candidateId, default: 0] += 1
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            await MainActor.run { errorText = error.localizedDescription }
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

    private func findAndAddMemberByName() async {
        usernameLookupHint = nil
        let q = usernameLookup.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        guard auth.currentUser?.id != nil else { return }
        let ids = await firestore.lookupUserIdsByExactDisplayName(q)
        await MainActor.run {
            if ids.isEmpty {
                usernameLookupHint = "No profile found with that exact name."
            } else if ids.count > 1 {
                usernameLookupHint = "Multiple matches—ask your friend to confirm their profile name."
            } else if let newId = ids.first {
                if memberIds.contains(newId) {
                    usernameLookupHint = "That person is already a member."
                } else {
                    usernameLookup = ""
                    usernameLookupHint = nil
                    memberIdPendingPastAccess = newId
                }
            }
        }
    }

    private func addMemberWithHistoryChoice(newId: String, canSeePast: Bool) async {
        guard let uid = auth.currentUser?.id else { return }
        do {
            try await firestore.addGroupMember(
                groupId: group.id,
                memberUserId: newId,
                actingUserId: uid,
                canSeePastMessages: canSeePast
            )
            await MainActor.run {
                if !memberIds.contains(newId) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        memberIds.append(newId)
                    }
                }
                usernameLookupHint = "Added to the group."
            }
        } catch {
            await MainActor.run {
                usernameLookupHint = error.localizedDescription
            }
        }
    }

    private func removeMember(_ memberUserId: String) async {
        guard let uid = auth.currentUser?.id else { return }
        do {
            try await firestore.removeGroupMember(groupId: group.id, memberUserId: memberUserId, actingUserId: uid)
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    memberIds.removeAll { $0 == memberUserId }
                }
            }
        } catch {
            await MainActor.run { errorText = error.localizedDescription }
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
