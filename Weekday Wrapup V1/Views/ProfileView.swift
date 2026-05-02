import SwiftUI

/// FILE: Views/ProfileView.swift
/// Public profile at `users/{userId}/profile/main`.

struct ProfileView: View {
    let userId: String
    /// When opened from a feed card, used to show gentle “support” prompts for high-intensity posts.
    var contextPost: FeedPost?

    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var profileManager: ProfileManager

    @State private var profile: UserProfile?
    @State private var profileDetails: ProfileDetails?
    @State private var supportSettings: SupportSettings = SupportSettings()
    @State private var fallbackName = "Member"
    @State private var showEditor = false
    /// Loaded only for **your** profile (onboarding preferences).
    @State private var selfPreferences: UserPreferences?
    @State private var postCountEligible = false
    @State private var insightDraft = ""
    @State private var showInsightEditor = false
    @State private var insightEditorText = ""
    @State private var insightError: String?
    @State private var showReportConfirm = false
    @State private var reportInFlight = false
    @State private var isFriend = false
    @State private var showMessageSheet = false
    @State private var showInviteSheet = false
    @State private var showGiftSheet = false
    @State private var isLoadingProfile = true

    private var isSelf: Bool { auth.currentUser?.id == userId }
    private var viewerId: String? { auth.currentUser?.id }

    private var isProfilePrivateToViewer: Bool {
        !isSelf && profile?.profileVisibility == PostVisibility.private.rawValue
    }

    private var showInsightPromptCard: Bool {
        guard isSelf else { return false }
        guard postCountEligible else { return false }
        let accepted = !(profileDetails?.insightSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        guard !accepted else { return false }
        return profileDetails?.insightPromptDismissed != true
    }

    private var supportVisibilityAllowsViewer: Bool {
        switch supportSettings.visibility {
        case .public:
            return true
        case .friends:
            return isFriend || isSelf
        case .privateMode:
            return isSelf
        }
    }

    private var supportModeAllowsViewer: Bool {
        switch supportSettings.supportMode {
        case .open:
            return true
        case .friendsOnly:
            return isFriend || isSelf
        case .privateMode:
            return isSelf
        }
    }

    private var supportTimeAllowsNow: Bool {
        if supportSettings.isSupportTodayEnabled {
            return supportSettings.isTemporarilyActiveNow
        }
        return true
    }

    private var shouldShowSupportCard: Bool {
        guard !isSelf else { return false }
        guard supportSettings.allowSupport else { return false }
        guard supportVisibilityAllowsViewer, supportModeAllowsViewer else { return false }
        return supportTimeAllowsNow
    }

    /// Recent wrapups by this user (from the live feed cache).
    private var recentAuthorPosts: [FeedPost] {
        firestore.posts
            .filter { $0.authorId == userId }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if isLoadingProfile {
                    ProgressView("Loading profile…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                headerBlock

                if !isLoadingProfile, profile == nil {
                    Text("We couldn't load this profile yet. Please try again.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBackground)
                }

                if let s = profileDetails?.insightSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty, isSelf {
                    profileInsightAcceptedCard(text: s)
                }

                if showInsightPromptCard {
                    profileInsightPromptCardView
                }

                if shouldShowSupportCard {
                    supportActionsCard
                }

                if isProfilePrivateToViewer {
                    privateProfileGate
                } else {
                    if showSupportStrip {
                        supportStrip
                    }

                    emotionalSnapshotSection

                    if isSelf {
                        thingsThatHelpSection
                    }

                    sectionCard(title: "What brings me joy", icon: "sparkles") {
                        chipGrid(profile?.joys ?? [])
                    }

                    sectionCard(title: "Things I like", icon: "heart.text.square") {
                        chipGrid(profile?.interests ?? [])
                    }

                    sectionCard(title: "How to support me", icon: "hands.sparkles") {
                        supportChips(profile?.prefersSupport ?? [])
                    }

                    waysToSupportContactSection

                    sectionCard(title: "Wishlist (links only)", icon: "link") {
                        wishlistLinks(profile?.wishlistLinks ?? [])
                    }

                    sectionCard(title: "Recent posts", icon: "clock.arrow.circlepath") {
                        recentPostsPreview
                    }
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
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showReportConfirm = true
                        } label: {
                            Label("Report user", systemImage: "exclamationmark.bubble")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(reportInFlight)
                }
            }
        }
        .confirmationDialog("Report this profile?", isPresented: $showReportConfirm, titleVisibility: .visible) {
            Button("Report", role: .destructive) {
                Task { await submitReport() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showInsightEditor) {
            NavigationStack {
                Form {
                    Section {
                        TextEditor(text: $insightEditorText)
                            .frame(minHeight: 180)
                    }
                }
                .navigationTitle("Edit summary")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showInsightEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task { await saveEditedInsightDraft() }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            EditProfileView(
                userId: userId,
                profile: profile ?? UserProfile(name: auth.currentUser?.name ?? "You"),
                details: profileDetails ?? ProfileDetails(),
                supportSettings: supportSettings
            )
            .environmentObject(firestore)
            .environmentObject(auth)
            .environmentObject(profileManager)
        }
        .sheet(isPresented: $showMessageSheet) {
            SupportMessageSheetView { text in
                Task { await sendSupportMessage(text: text) }
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            SupportInviteSheetView { activity in
                Task { await sendSupportInvite(activity: activity) }
            }
        }
        .sheet(isPresented: $showGiftSheet) {
            SupportGiftSheetView(
                links: profileDetails?.wishlistLinks ?? profile?.wishlistLinks ?? []
            ) { link in
                Task { await sendSupportGift(link: link) }
            }
        }
        .onChange(of: showEditor) { _, open in
            if !open {
                Task { await load(forceRefresh: true) }
            }
        }
        .task { await load(forceRefresh: false) }
    }

    @ViewBuilder
    private var favoriteSongLine: some View {
        if profile?.showFavoriteSong != false {
            let song = profile?.favoriteSong?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let artist = profile?.favoriteArtist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !song.isEmpty || !artist.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    if !song.isEmpty {
                        Label(song, systemImage: "music.note")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.colors.textPrimary)
                    }
                    if !artist.isEmpty {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(AppTheme.colors.textSecondary)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private var venmoLine: some View {
        if profile?.showVenmoUsername == true {
            let venmo = profile?.venmoUsername?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !venmo.isEmpty {
                Label("@\(venmo.replacingOccurrences(of: "@", with: ""))", systemImage: "dollarsign.circle")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 16) {
            profileAvatar
            VStack(alignment: .leading, spacing: 8) {
                Text(profile?.name ?? fallbackName)
                    .font(.title.bold())
                    .foregroundStyle(AppTheme.colors.textPrimary)
                Text("@\(String(userId.prefix(8)))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.colors.textSecondary)
                if supportSettings.allowSupport && supportSettings.isTemporarilyActiveNow {
                    Text("Open to support today 💛")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.yellow.opacity(0.18)))
                        .transition(.opacity)
                }

                if let pronouns = profile?.pronouns, !pronouns.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(pronouns)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.colors.textSecondary)
                }
                if let rs = profile?.relationshipStatus, !rs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(rs)
                        .font(.caption)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                }
                if let loc = LocationDisplay.coarse(profile?.location), !loc.isEmpty {
                    Label(loc, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                }
                if let school = profile?.school, !school.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(school, systemImage: "graduationcap")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                }
                favoriteSongLine
                venmoLine
                if let bio = profile?.bio, !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(bio)
                        .font(.body)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    @ViewBuilder
    private var profileAvatar: some View {
        let urlString = profile?.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let url = URL(string: urlString), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderAvatar
                case .empty:
                    ProgressView()
                        .frame(width: 72, height: 72)
                @unknown default:
                    placeholderAvatar
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.colors.sand.opacity(0.35), lineWidth: 1))
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 72, height: 72)
            .foregroundStyle(AppTheme.colors.ocean.opacity(0.85))
    }

    @ViewBuilder
    private var emotionalSnapshotSection: some View {
        let posts = Array(recentAuthorPosts.prefix(12))
        sectionCard(title: "Emotional snapshot", icon: "chart.bar.xaxis") {
            if posts.isEmpty {
                Text("No recent wrapups in the feed yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
            } else {
                Text("Most common emotions (recent)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.colors.textSecondary)
                let tallies = emotionTallies(from: posts)
                if tallies.isEmpty {
                    Text("—")
                        .foregroundStyle(AppTheme.colors.textSecondary)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(tallies.prefix(5), id: \.0) { pair in
                            Text("\(pair.0) · \(pair.1)")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(FeedEmotionPalette.chipBackground(for: pair.0)))
                                .foregroundStyle(FeedEmotionPalette.chipForeground(for: pair.0))
                        }
                    }
                }
                Divider().padding(.vertical, 6)
                Text(emotionTrendLine(from: posts))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var thingsThatHelpSection: some View {
        sectionCard(title: "Things that help me", icon: "leaf") {
            if let p = selfPreferences {
                VStack(alignment: .leading, spacing: 8) {
                    if !p.topJoyActivities.isEmpty {
                        Text("Joy activities")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.colors.textSecondary)
                        chipGrid(p.topJoyActivities)
                    }
                    if let styles = p.preferredCopingStyles, !styles.isEmpty {
                        Text("Coping styles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.colors.textSecondary)
                            .padding(.top, 4)
                        chipGrid(styles)
                    }
                    if p.topJoyActivities.isEmpty && (p.preferredCopingStyles?.isEmpty ?? true) {
                        Text("Finish onboarding preferences to personalize this.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.colors.textSecondary)
                    }
                }
            } else {
                Text("Loading…")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var waysToSupportContactSection: some View {
        let sp = profile?.supportPreferences
        if sp?.allowContact != true {
            if isSelf {
                sectionCard(title: "Ways to support me", icon: "phone.badge.plus") {
                    Text("Turn on “Allow others to support me” in Edit to share contact options.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                }
            }
        } else {
            sectionCard(title: "Ways to support me", icon: "phone.badge.plus") {
                if sp?.appUsersOnly == true {
                    Text("They prefer messages from people in this app first.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                }
                if sp?.appUsersOnly != true || isSelf {
                    let methods = sp?.contactMethods ?? []
                    let showPhone = methods.contains("phone") || (sp?.phoneNumber?.isEmpty == false)
                    let showEmail = methods.contains("email") || (sp?.email?.isEmpty == false)
                    if showPhone, let phone = sp?.phoneNumber, !phone.isEmpty {
                        LabeledContent("Phone") {
                            Text(phone)
                                .font(.subheadline.weight(.semibold))
                                .textSelection(.enabled)
                        }
                    }
                    if showEmail, let email = sp?.email, !email.isEmpty {
                        LabeledContent("Email") {
                            Text(email)
                                .font(.subheadline.weight(.semibold))
                                .textSelection(.enabled)
                        }
                    }
                    if !isSelf && sp?.appUsersOnly != true && !showPhone && !showEmail {
                        Text("They’re open to support—say hello in the feed or comments.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.colors.textSecondary)
                    }
                }
            }
        }
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
                Label("Encourage", systemImage: "heart.text.square")
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

    private var showSupportStrip: Bool {
        guard !isSelf, let p = contextPost, p.authorId == userId else { return false }
        return (p.intensity ?? 0) >= 8
    }

    private var supportActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Support \(profile?.name ?? fallbackName)")
                .font(.headline)
                .foregroundStyle(AppTheme.colors.textPrimary)
            Text("Choose a low-pressure way to show up.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if supportSettings.allowMessages {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showMessageSheet = true
                    } label: {
                        Label("Message", systemImage: "bubble.left.and.bubble.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
                if supportSettings.allowInvites {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showInviteSheet = true
                    } label: {
                        Label("Invite", systemImage: "figure.walk")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
                if supportSettings.allowGifts {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showGiftSheet = true
                    } label: {
                        Label("Send Gift", systemImage: "gift")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.colors.mist.opacity(0.35))
        )
    }

    @ViewBuilder
    private var recentPostsPreview: some View {
        let recent = Array(recentAuthorPosts.prefix(3))
        if recent.isEmpty {
            Text("No recent posts yet.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.colors.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(recent) { post in
                    NavigationLink(value: post) {
                        HStack(alignment: .top, spacing: 10) {
                            Text(post.emoji)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(post.insight.isEmpty ? "Shared a weekly wrapup" : post.insight)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                Text(RelativeTimeFormat.string(for: post.createdAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
        let valid = links.compactMap { line -> String? in
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, let url = URL(string: t), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
                return nil
            }
            return t
        }
        return Group {
            if valid.isEmpty {
                if links.isEmpty {
                    Text("—")
                        .foregroundStyle(AppTheme.colors.textSecondary)
                } else {
                    Text("Add full https links so others can open them safely.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.colors.textSecondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(valid, id: \.self) { raw in
                        if let url = URL(string: raw) {
                            Link(destination: url) {
                                Text(raw)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.colors.ocean)
                                    .lineLimit(2)
                            }
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
        case "encouragement": return "A few kind words or encouragement"
        case "resource_share": return "Helpful articles or resources"
        default: return key
        }
    }

    private func emotionTallies(from posts: [FeedPost]) -> [(String, Int)] {
        var counts: [String: Int] = [:]
        for p in posts {
            for raw in p.selectedEmotions {
                let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { continue }
                counts[key, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private func emotionTrendLine(from posts: [FeedPost]) -> String {
        let dated = posts.compactMap { p -> (Date, Int)? in
            guard let d = p.createdAt, let i = p.intensity else { return nil }
            return (d, i)
        }
        .sorted { $0.0 < $1.0 }
        guard dated.count >= 4 else {
            return "Trend: add a few more wrapups with intensity to see whether things are improving week to week."
        }
        let last = Array(dated.suffix(3).map(\.1))
        let prev = Array(dated.dropLast(3).suffix(3).map(\.1))
        guard !last.isEmpty, !prev.isEmpty else {
            return "Trend: keep logging—your pattern will emerge."
        }
        let a = Double(last.reduce(0, +)) / Double(last.count)
        let b = Double(prev.reduce(0, +)) / Double(prev.count)
        if a + 0.75 < b {
            return "Trend: intensity looks improving lately (recent weeks a bit lighter than before)."
        }
        if a > b + 0.75 {
            return "Trend: intensity has been a bit higher recently—extra gentleness may help."
        }
        return "Trend: roughly steady lately—small routines still count."
    }

    private var privateProfileGate: some View {
        Text("This person keeps profile details private. Kind reactions on their posts still land gently.")
            .font(.subheadline)
            .foregroundStyle(AppTheme.colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
    }

    @ViewBuilder
    private func profileInsightAcceptedCard(text: String) -> some View {
        sectionCard(title: "About you", icon: "text.quote") {
            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var profileInsightPromptCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Want to add this to your profile?")
                .font(.headline)
                .foregroundStyle(AppTheme.colors.textPrimary)
            Text(insightDraft)
                .font(.subheadline)
                .foregroundStyle(AppTheme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let e = insightError {
                Text(e)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await acceptInsightSummary() }
                } label: {
                    Text("Add to profile")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(AppTheme.colors.pine.opacity(0.2)))
                }
                .buttonStyle(.plain)

                Button {
                    insightEditorText = insightDraft
                    showInsightEditor = true
                } label: {
                    Text("Edit")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer(minLength: 8)

                Button("Dismiss") {
                    Task { await dismissInsightPrompt() }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.colors.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func acceptInsightSummary() async {
        insightError = nil
        guard let uid = auth.currentUser?.id else { return }
        let text = insightDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            await MainActor.run { insightError = "Summary is empty—tap Edit to add a line or two." }
            return
        }
        var d = profileDetails ?? ProfileDetails()
        d.insightSummary = text
        d.insightPromptDismissed = false
        do {
            try await firestore.saveProfileDetails(d, userId: uid)
            await MainActor.run { profileDetails = d }
        } catch {
            await MainActor.run { insightError = error.localizedDescription }
        }
    }

    private func dismissInsightPrompt() async {
        guard let uid = auth.currentUser?.id else { return }
        var d = profileDetails ?? ProfileDetails()
        d.insightPromptDismissed = true
        do {
            try await firestore.saveProfileDetails(d, userId: uid)
            await MainActor.run { profileDetails = d }
        } catch {
            await MainActor.run { insightError = error.localizedDescription }
        }
    }

    private func saveEditedInsightDraft() async {
        let next = insightEditorText.trimmingCharacters(in: .whitespacesAndNewlines)
        await MainActor.run {
            insightDraft = next
            showInsightEditor = false
        }
    }

    private func submitReport() async {
        guard let rid = auth.currentUser?.id else { return }
        await MainActor.run { reportInFlight = true }
        defer {
            Task { @MainActor in reportInFlight = false }
        }
        do {
            try await firestore.submitUserReport(reporterId: rid, reportedUserId: userId, reason: "profile_report")
        } catch {
            print("⚠️ report: \(error.localizedDescription)")
        }
    }

    private func sendSupportMessage(text: String) async {
        guard let from = viewerId, from != userId else { return }
        guard supportSettings.allowSupport, supportSettings.allowMessages, shouldShowSupportCard else { return }
        do {
            try await firestore.sendSupportMessage(fromUserId: from, targetUserId: userId, text: text)
        } catch {
            print("⚠️ support message: \(error.localizedDescription)")
        }
    }

    private func sendSupportInvite(activity: String) async {
        guard let from = viewerId, from != userId else { return }
        guard supportSettings.allowSupport, supportSettings.allowInvites, shouldShowSupportCard else { return }
        do {
            try await firestore.sendSupportInvite(fromUserId: from, targetUserId: userId, activity: activity)
        } catch {
            print("⚠️ support invite: \(error.localizedDescription)")
        }
    }

    private func sendSupportGift(link: String) async {
        guard let from = viewerId, from != userId else { return }
        guard supportSettings.allowSupport, supportSettings.allowGifts, shouldShowSupportCard else { return }
        let title = URL(string: link)?.host ?? "Gift idea"
        do {
            try await firestore.sendSupportGift(
                fromUserId: from,
                targetUserId: userId,
                itemTitle: title,
                itemURL: link
            )
        } catch {
            print("⚠️ support gift: \(error.localizedDescription)")
        }
    }

    private func load(forceRefresh: Bool) async {
        await MainActor.run {
            isLoadingProfile = true
        }
        let name = await firestore.userDisplayName(userId: userId)
        async let profileTask = profileManager.loadProfile(userId: userId, forceRefresh: forceRefresh)
        async let detailsTask = firestore.fetchProfileDetails(userId: userId)
        async let supportTask = firestore.fetchSupportSettings(userId: userId)
        async let eligibleTask = firestore.hasAtLeastPosts(authorId: userId, minimum: 10)
        async let friendTask: Bool = {
            guard let viewer = viewerId else { return false }
            return await firestore.isFriend(currentUserId: viewer, otherUserId: userId)
        }()

        var prefs: UserPreferences?
        if isSelf {
            prefs = await firestore.fetchUserPreferences(userId: userId)
        }

        let prof = await profileTask
        let det = await detailsTask
        var support = await supportTask ?? SupportSettings()
        let eligible = await eligibleTask
        let friend = await friendTask

        if support.isExpiredNow, isSelf {
            support.isSupportTodayEnabled = false
            support.supportExpiresAt = nil
            try? await firestore.saveSupportSettings(support, userId: userId)
        }

        let postsSnapshot = firestore.posts
            .filter { $0.authorId == userId }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }

        await MainActor.run {
            fallbackName = name
            profile = prof
            profileDetails = det
            withAnimation(.easeInOut(duration: 0.25)) {
                supportSettings = support
            }
            isFriend = friend
            postCountEligible = eligible
            selfPreferences = prefs
            isLoadingProfile = false
            if isSelf, eligible {
                insightDraft = ProfileInsightEngine.generateDraft(
                    preferredName: prof?.name ?? name,
                    preferences: prefs,
                    recentPosts: Array(postsSnapshot.prefix(12))
                )
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ProfileView(userId: "u1", contextPost: nil)
            .environmentObject(FirestoreManager.shared)
            .environmentObject(AuthManager(previewLoggedIn: true, previewUser: PreviewSampleData.currentUser))
            .environmentObject(ProfileManager.shared)
    }
}
#endif
