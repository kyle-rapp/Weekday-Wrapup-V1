import SwiftUI

/// FILE: Views/CreateGroupView.swift
/// Create a `groups` document: name, optional description, optional members from people you follow, optional email/phone invites.

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    @State private var name = ""
    @State private var descriptionText = ""
    @State private var selectedMemberIds = Set<String>()
    @State private var displayNames: [String: String] = [:]
    @State private var inviteInput = ""
    @State private var pendingInvites: [String] = []
    @State private var isSaving = false
    @State private var errorText: String?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && auth.currentUser != nil
    }

    var body: some View {
        Form {
            Section {
                TextField("Group name", text: $name)
                    .textInputAutocapitalization(.words)

                TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                    .lineLimit(2...5)
            } header: {
                Text("Details")
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
                Text("Invites (optional)")
            } footer: {
                Text("Stored as contact strings until they join the app.")
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    Text("Create Group")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canSave || isSaving)
            }

            if !firestore.followingIds.isEmpty {
                Section {
                    ForEach(firestore.followingIds.sorted(), id: \.self) { id in
                        Toggle(isOn: Binding(
                            get: { selectedMemberIds.contains(id) },
                            set: { on in
                                if on { selectedMemberIds.insert(id) } else { selectedMemberIds.remove(id) }
                            }
                        )) {
                            Text(displayNames[id] ?? "…")
                        }
                    }
                } header: {
                    Text("Invite members (optional)")
                } footer: {
                    Text("You are included automatically.")
                }
            }
        }
        .navigationTitle("New group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .task {
            await loadNames()
        }
        .alert("Couldn’t create group", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
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

    private func loadNames() async {
        for id in firestore.followingIds {
            let n = await firestore.userDisplayName(userId: id)
            await MainActor.run {
                displayNames[id] = n
            }
        }
    }

    private func save() async {
        guard let uid = auth.currentUser?.id else { return }
        isSaving = true
        defer { isSaving = false }
        let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let invites = pendingInvites
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        do {
            try await firestore.createGroup(
                name: name,
                description: desc.isEmpty ? nil : desc,
                memberIds: Array(selectedMemberIds),
                ownerId: uid,
                invitedContacts: invites.isEmpty ? nil : invites,
                allowHistoryAccessForNewMembers: nil
            )
            await MainActor.run { dismiss() }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CreateGroupView()
    }
    .environmentObject(FirestoreManager.shared)
    .environmentObject(AuthManager(previewLoggedIn: true, previewUser: PreviewSampleData.currentUser))
}
#endif
