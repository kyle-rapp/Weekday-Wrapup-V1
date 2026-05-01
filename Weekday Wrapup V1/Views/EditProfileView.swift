import SwiftUI

/// FILE: Views/EditProfileView.swift
/// Full profile editor backed by merge writes.

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var profileManager: ProfileManager

    let userId: String
    let initialProfile: UserProfile
    let initialDetails: ProfileDetails
    let initialSupportSettings: SupportSettings

    @State private var displayName: String
    @State private var username: String
    @State private var bio: String
    @State private var location: String
    @State private var school: String
    @State private var pronouns: String
    @State private var relationshipStatus: String
    @State private var favoriteSong: String
    @State private var interestsRaw: String
    @State private var wishlistLinks: [String]
    @State private var insightSummary: String
    @State private var allowSupport: Bool
    @State private var supportMode: SupportMode
    @State private var isSupportTodayEnabled: Bool
    @State private var supportExpiresAt: Date?
    @State private var supportVisibility: SupportVisibility
    @State private var allowMessages: Bool
    @State private var allowInvites: Bool
    @State private var allowGifts: Bool
    @State private var isSaving = false
    @State private var errorText: String?

    init(userId: String, profile: UserProfile, details: ProfileDetails, supportSettings: SupportSettings) {
        self.userId = userId
        self.initialProfile = profile
        self.initialDetails = details
        self.initialSupportSettings = supportSettings
        _displayName = State(initialValue: profile.name ?? "")
        _username = State(initialValue: "@\(String(userId.prefix(8)))")
        _bio = State(initialValue: profile.bio ?? "")
        _location = State(initialValue: profile.location ?? "")
        _school = State(initialValue: profile.school ?? "")
        _pronouns = State(initialValue: profile.pronouns ?? "")
        _relationshipStatus = State(initialValue: profile.relationshipStatus ?? "")
        _favoriteSong = State(initialValue: profile.favoriteSong ?? "")
        _interestsRaw = State(initialValue: (profile.interests ?? []).joined(separator: ", "))
        let links = details.wishlistLinks ?? profile.wishlistLinks ?? []
        _wishlistLinks = State(initialValue: links.isEmpty ? [""] : links)
        _insightSummary = State(initialValue: details.insightSummary ?? "")
        _allowSupport = State(initialValue: supportSettings.allowSupport)
        _supportMode = State(initialValue: supportSettings.supportMode)
        _isSupportTodayEnabled = State(initialValue: supportSettings.isSupportTodayEnabled)
        _supportExpiresAt = State(initialValue: supportSettings.supportExpiresAt)
        _supportVisibility = State(initialValue: supportSettings.visibility)
        _allowMessages = State(initialValue: supportSettings.allowMessages)
        _allowInvites = State(initialValue: supportSettings.allowInvites)
        _allowGifts = State(initialValue: supportSettings.allowGifts)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Display name", text: $displayName)
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(2 ... 5)
                }

                Section("Info") {
                    TextField("Location", text: $location)
                    TextField("School", text: $school)
                    TextField("Pronouns", text: $pronouns)
                    TextField("Relationship status", text: $relationshipStatus)
                }

                Section("Favorite song") {
                    TextField("Favorite song", text: $favoriteSong)
                }

                Section("Interests") {
                    TextField("Interests (comma-separated)", text: $interestsRaw, axis: .vertical)
                        .lineLimit(2 ... 4)
                }

                Section("Insight summary") {
                    TextField("Optional summary", text: $insightSummary, axis: .vertical)
                        .lineLimit(2 ... 5)
                }

                Section {
                    ForEach(wishlistLinks.indices, id: \.self) { idx in
                        HStack(spacing: 10) {
                            TextField("https://example.com", text: Binding(
                                get: { wishlistLinks[idx] },
                                set: { wishlistLinks[idx] = $0 }
                            ))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                            if wishlistLinks.count > 1 {
                                Button(role: .destructive) {
                                    wishlistLinks.remove(at: idx)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        wishlistLinks.append("")
                    } label: {
                        Label("Add link", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Wishlist links")
                }
                
                Section {
                    Text("Choose how others can show up for you")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle(isOn: $allowSupport) {
                        Label("I’m open to support", systemImage: "hands.sparkles")
                    }
                    Group {
                        Picker("Support mode", selection: $supportMode) {
                            Text("Anyone").tag(SupportMode.open)
                            Text("Friends").tag(SupportMode.friendsOnly)
                            Text("No one").tag(SupportMode.privateMode)
                        }
                        .pickerStyle(.segmented)

                        Toggle(isOn: Binding(
                            get: { isSupportTodayEnabled },
                            set: { newValue in
                                isSupportTodayEnabled = newValue
                                if newValue {
                                    supportExpiresAt = Date().addingTimeInterval(24 * 60 * 60)
                                } else {
                                    supportExpiresAt = nil
                                }
                            }
                        )) {
                            Label("I want support today", systemImage: "sun.max")
                        }
                        if isSupportTodayEnabled, let supportExpiresAt {
                            Text("Ends \(supportExpiresAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Picker("Visibility", selection: $supportVisibility) {
                            Text("Public").tag(SupportVisibility.public)
                            Text("Friends").tag(SupportVisibility.friends)
                            Text("Private").tag(SupportVisibility.privateMode)
                        }
                        .pickerStyle(.segmented)

                        Toggle("Allow messages", isOn: $allowMessages)
                        Toggle("Allow invites", isOn: $allowInvites)
                        Toggle("Allow gifts", isOn: $allowGifts)
                    }
                    .disabled(!allowSupport)
                    .opacity(allowSupport ? 1 : 0.55)
                } header: {
                    Text("Support Preferences")
                }

                if let errorText, !errorText.isEmpty {
                    Section {
                        Text(errorText)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
        }
        .onAppear {
            expireSupportIfNeeded()
        }
    }

    private func splitCommaList(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        guard let uid = auth.currentUser?.id, uid == userId else {
            errorText = "Auth mismatch. Please sign in again."
            return
        }

        let cleanName = trimmed(displayName)
        guard !cleanName.isEmpty else {
            errorText = "Display name cannot be empty."
            return
        }

        let cleanUsernameRaw = trimmed(username)
        let cleanUsername = cleanUsernameRaw.hasPrefix("@") ? cleanUsernameRaw : "@\(cleanUsernameRaw)"
        let cleanWishlist = wishlistLinks
            .map(trimmed)
            .filter { !$0.isEmpty }
        expireSupportIfNeeded()

        let profile = UserProfile(
            name: cleanName,
            bio: trimmed(bio).isEmpty ? nil : trimmed(bio),
            profileImageURL: initialProfile.profileImageURL,
            location: trimmed(location).isEmpty ? nil : trimmed(location),
            school: trimmed(school).isEmpty ? nil : trimmed(school),
            pronouns: trimmed(pronouns).isEmpty ? nil : trimmed(pronouns),
            relationshipStatus: trimmed(relationshipStatus).isEmpty ? nil : trimmed(relationshipStatus),
            supportPreferences: initialProfile.supportPreferences,
            interests: splitCommaList(interestsRaw),
            joys: initialProfile.joys,
            wishlistLinks: cleanWishlist,
            isOpenToMeetups: initialProfile.isOpenToMeetups,
            prefersSupport: initialProfile.prefersSupport,
            favoriteSong: trimmed(favoriteSong).isEmpty ? nil : trimmed(favoriteSong),
            favoriteArtist: initialProfile.favoriteArtist,
            profileVisibility: initialProfile.profileVisibility
        )

        var details = initialDetails
        let summary = trimmed(insightSummary)
        details.insightSummary = summary.isEmpty ? nil : summary
        details.wishlistLinks = cleanWishlist

        let settings = SupportSettings(
            allowSupport: allowSupport,
            supportMode: supportMode,
            isSupportTodayEnabled: isSupportTodayEnabled,
            supportExpiresAt: supportExpiresAt,
            visibility: supportVisibility,
            allowMessages: allowMessages,
            allowInvites: allowInvites,
            allowGifts: allowGifts
        )

        do {
            try await firestore.saveProfileSystem(
                userId: uid,
                displayName: cleanName,
                username: cleanUsername,
                profile: profile,
                details: details
            )
            try await firestore.saveSupportSettings(settings, userId: uid)
            profileManager.invalidate(userId: uid)
            await MainActor.run { dismiss() }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func expireSupportIfNeeded() {
        guard isSupportTodayEnabled, let supportExpiresAt else { return }
        if Date() > supportExpiresAt {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSupportTodayEnabled = false
                self.supportExpiresAt = nil
            }
        }
    }
}

