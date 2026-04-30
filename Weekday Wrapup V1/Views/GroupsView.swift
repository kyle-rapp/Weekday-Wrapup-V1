import SwiftUI

/// FILE: Views/GroupsView.swift
/// Lists groups the current user belongs to; create flow in `CreateGroupView`.

struct GroupsView: View {
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager
    @State private var showingCreateGroup = false

    var body: some View {
        Group {
            if firestore.myGroups.isEmpty {
                ContentUnavailableView(
                    "No groups yet",
                    systemImage: "person.3",
                    description: Text("Create a group to share wrapups with a small circle from the Share tab.")
                )
            } else {
                List {
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
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
