import SwiftUI

/// FILE: Views/ProfileView.swift
/// Public profile at `users/{userId}/profile/main`.

struct ProfileView: View {
    let userId: String
    /// When opened from a feed card, used to show gentle “support” prompts for high-intensity posts.
    var contextPost: FeedPost?

    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    @State private var profile: UserProfile?
    @State private var fallbackName = "Member"
    @State private var showEditor = false

    private var isSelf: Bool { auth.currentUser?.id == userId }

    private var showSupportStrip: Bool {
        guard !isSelf, let p = contextPost, p.authorId == userId else { return false }
        return (p.intensity ?? 0) >= 8
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerBlock

                if showSupportStrip {
                    supportStrip
                }

                sectionCard(title: "What brings me joy", icon: "sparkles") {
                    chipGrid(profile?.joys ?? [])
                }

                sectionCard(title: "Things I like", icon: "heart.text.square") {
                    chipGrid(profile?.interests ?? [])
                }

                sectionCard(title: "Wishlist", icon: "gift") {
                    wishlistLinks(profile?.wishlistLinks ?? [])
                }

                sectionCard(title: "How to support me", icon: "hands.sparkles") {
                    supportChips(profile?.prefersSupport ?? [])
                }
            }
            .padding(20)
        }
        .background(AppTheme.colors.secondaryBackground.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSelf {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEditor = true }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            ProfileEditorSheet(
                profile: profile ?? UserProfile(name: auth.currentUser?.name ?? "You"),
                userId: userId
            )
            .environmentObject(firestore)
            .environmentObject(auth)
        }
        .task { await load() }
    }

    @ViewBuilder
    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(profile?.name ?? fallbackName)
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.colors.textPrimary)

            if let loc = profile?.location, !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label(loc, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
            }
            if let school = profile?.school, !school.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label(school, systemImage: "graduationcap")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
            }
            if let bio = profile?.bio, !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(bio)
                    .font(.body)
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    private var supportStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Support this person")
                .font(.headline)
                .foregroundStyle(AppTheme.colors.textPrimary)
            Text("They shared a heavy week. Small gestures can help more than big speeches.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Label("Message", systemImage: "bubble.left.and.bubble.right")
                Label("Invite out", systemImage: "figure.walk")
                Label("Wishlist", systemImage: "gift")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.colors.ocean)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(AppTheme.colors.textPrimary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AppTheme.colors.background)
            .shadow(color: AppTheme.colors.bark.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private func chipGrid(_ items: [String]) -> some View {
        Group {
            if items.isEmpty {
                Text("—")
                    .foregroundStyle(AppTheme.colors.textSecondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(items, id: \.self) { t in
                        Text(t)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(AppTheme.colors.mist.opacity(0.45)))
                    }
                }
            }
        }
    }

    private func wishlistLinks(_ links: [String]) -> some View {
        Group {
            if links.isEmpty {
                Text("—")
                    .foregroundStyle(AppTheme.colors.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(links, id: \.self) { raw in
                        if let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                           let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                            Link(destination: url) {
                                Text(raw)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.colors.ocean)
                                    .lineLimit(2)
                            }
                        } else {
                            Text(raw)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.colors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func supportChips(_ prefs: [String]) -> some View {
        Group {
            if prefs.isEmpty {
                Text("—")
                    .foregroundStyle(AppTheme.colors.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(prefs, id: \.self) { pref in
                        Text("• \(supportLabel(pref))")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.colors.textSecondary)
                    }
                }
            }
        }
    }

    private func supportLabel(_ key: String) -> String {
        switch key.lowercased() {
        case "talk": return "Check in with a call or text"
        case "activity": return "Invite me to something low-key"
        case "gifts": return "Small surprises or wishlist picks"
        default: return key
        }
    }

    private func load() async {
        let name = await firestore.userDisplayName(userId: userId)
        let p = await firestore.fetchUserProfile(userId: userId)
        await MainActor.run {
            fallbackName = name
            profile = p
        }
    }
}

// MARK: - Editor

private struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    let userId: String
    @State private var name: String
    @State private var bio: String
    @State private var location: String
    @State private var school: String
    @State private var joys: String
    @State private var interests: String
    @State private var wishlist: String
    @State private var meetups: Bool
    @State private var supportTalk: Bool
    @State private var supportActivity: Bool
    @State private var supportGifts: Bool
    @State private var isSaving = false
    @State private var errorText: String?

    init(profile: UserProfile, userId: String) {
        self.userId = userId
        _name = State(initialValue: profile.name)
        _bio = State(initialValue: profile.bio ?? "")
        _location = State(initialValue: profile.location ?? "")
        _school = State(initialValue: profile.school ?? "")
        _joys = State(initialValue: profile.joys.joined(separator: ", "))
        _interests = State(initialValue: profile.interests.joined(separator: ", "))
        _wishlist = State(initialValue: profile.wishlistLinks.joined(separator: "\n"))
        _meetups = State(initialValue: profile.isOpenToMeetups ?? false)
        _supportTalk = State(initialValue: profile.prefersSupport?.contains("talk") ?? false)
        _supportActivity = State(initialValue: profile.prefersSupport?.contains("activity") ?? false)
        _supportGifts = State(initialValue: profile.prefersSupport?.contains("gifts") ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $name)
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Location", text: $location)
                    TextField("School", text: $school)
                }
                Section("Joy & interests") {
                    TextField("Joys (comma-separated)", text: $joys, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Interests (comma-separated)", text: $interests, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Wishlist") {
                    TextField("One link per line", text: $wishlist, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("Support preferences") {
                    Toggle("Open to meetups", isOn: $meetups)
                    Toggle("Likes check-ins (talk)", isOn: $supportTalk)
                    Toggle("Likes invites (activity)", isOn: $supportActivity)
                    Toggle("Likes small gifts", isOn: $supportGifts)
                }
                if let msg = errorText, !msg.isEmpty {
                    Section {
                        Text(msg)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
        }
    }

    private func splitList(_ raw: String) -> [String] {
        raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func wishlistLines(_ raw: String) -> [String] {
        raw.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        var prefs: [String] = []
        if supportTalk { prefs.append("talk") }
        if supportActivity { prefs.append("activity") }
        if supportGifts { prefs.append("gifts") }
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (auth.currentUser?.name ?? "Member") : name.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
            school: school.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : school.trimmingCharacters(in: .whitespacesAndNewlines),
            joys: splitList(joys),
            interests: splitList(interests),
            wishlistLinks: wishlistLines(wishlist),
            isOpenToMeetups: meetups,
            prefersSupport: prefs.isEmpty ? nil : prefs
        )
        do {
            try await firestore.saveUserProfile(profile, userId: userId)
            await MainActor.run { dismiss() }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ProfileView(userId: "u1", contextPost: nil)
            .environmentObject(FirestoreManager.shared)
            .environmentObject(AuthManager(previewLoggedIn: true, previewUser: PreviewSampleData.currentUser))
    }
}
#endif
