import SwiftUI

/// FILE: Views/GroupsView.swift
/// Lists groups the current user belongs to; create flow in `CreateGroupView`.

struct GroupsView: View {
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager
    @State private var showingCreateGroup = false
    @State private var joiningSuggestedGroupNames: Set<String> = []
    @State private var seededDefaultsForUserId: String?

    private var myGroupNameSet: Set<String> {
        Set(firestore.myGroups.map { $0.name.lowercased() })
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Explore communities that match what you're going through")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 10) {
                        NavigationLink {
                            GroupSearchView()
                                .environmentObject(firestore)
                                .environmentObject(auth)
                        } label: {
                            Text("Browse groups")
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Join suggested group") {
                            Task { await quickJoinFirstSuggestion() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Section("Suggested communities for you") {
                ForEach(DefaultGroups.all, id: \.self) { groupName in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(groupName)
                                .font(.subheadline.weight(.semibold))
                            Text("Low-pressure support community")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        let isJoined = myGroupNameSet.contains(groupName.lowercased())
                        let isJoining = joiningSuggestedGroupNames.contains(groupName)
                        Button(isJoined ? "Joined" : (isJoining ? "Joining…" : "Join")) {
                            Task { await joinSuggestedGroup(named: groupName) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isJoined || isJoining)
                    }
                }
            }

            Section("Your groups") {
                if firestore.myGroups.isEmpty {
                    Text("No groups joined yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(firestore.myGroups) { group in
                        NavigationLink {
                            GroupSettingsView(group: group)
                                .environmentObject(firestore)
                                .environmentObject(auth)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(group.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Label("\(group.memberIds.count) members", systemImage: "person.2.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let invites = group.invitedContacts, !invites.isEmpty {
                                    Text("\(invites.count) pending invite\(invites.count == 1 ? "" : "s")")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    GroupSearchView()
                        .environmentObject(firestore)
                        .environmentObject(auth)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Search groups")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreateGroup = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Create group")
            }
        }
        .sheet(isPresented: $showingCreateGroup) {
            NavigationStack {
                CreateGroupView()
            }
            .environmentObject(firestore)
            .environmentObject(auth)
        }
        .task(id: auth.currentUser?.id) {
            let uid = auth.currentUser?.id ?? "_none"
            guard seededDefaultsForUserId != uid else { return }
            seededDefaultsForUserId = uid
            await firestore.loadDiscoverableGroups(forceRefresh: true)
            #if DEBUG
            let discoverableNames = firestore.discoverableGroups.map { $0.name.lowercased() }
            let hasBurnout = discoverableNames.contains { $0.contains("burnout") }
            let hasPTSD = discoverableNames.contains { $0 == "ptsd" || $0.contains("post traumatic stress") || $0.contains("post-traumatic stress") }
            print("[GROUP_SEARCH][GROUPS_VIEW] seeded uid=\(uid) myGroups=\(firestore.myGroups.count) discoverable=\(firestore.discoverableGroups.count) hasBurnout=\(hasBurnout) hasPTSD=\(hasPTSD)")
            #endif
        }
    }

    private func quickJoinFirstSuggestion() async {
        let target = DefaultGroups.all.first { !myGroupNameSet.contains($0.lowercased()) }
        guard let target else { return }
        await joinSuggestedGroup(named: target)
    }

    private func joinSuggestedGroup(named groupName: String) async {
        guard let myId = auth.currentUser?.id else { return }
        if joiningSuggestedGroupNames.contains(groupName) { return }
        joiningSuggestedGroupNames.insert(groupName)
        defer { joiningSuggestedGroupNames.remove(groupName) }
        do {
            try await firestore.joinSuggestedGroup(named: groupName, userId: myId)
        } catch {
            AppLogger.error("joinSuggestedGroup failed: \(error.localizedDescription)")
        }
    }
}

#if DEBUG
#Preview("Groups (empty)") {
    NavigationStack {
        GroupsView()
    }
    .environmentObject(FirestoreManager.shared)
    .environmentObject(AuthManager(previewLoggedIn: true, previewUser: PreviewSampleData.currentUser))
}
#endif
