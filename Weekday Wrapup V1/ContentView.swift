//
//  ContentView.swift
//  Weekday Wrapup V1
//
//  Created by Shannon  Dupont on 12/14/24.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var emotionRouter: EmotionRouter

    // State variables
    @State private var showProfileCreation = false
    @State private var userName = ""
    @State private var profileImage: Image?
    @State private var profileImageURL = ""
    @State private var profileUIImage: UIImage?
    @State private var astrologySign = ""
    @State private var shareProfileNeedsBasicSetup = false
    @State private var weeklyEmoji = ""
    @State private var emotionalInsight = ""
    @State private var gratitudeText = ""
    @State private var whoopsText = ""
    @State private var poopsText = ""
    @State private var lookForwardTo = ""
    @State private var postTitle = ""
    @State private var capturedImage: UIImage?
    @State private var capturedVideoURL: URL?
    @State private var mediaError: String?
    @State private var visibility: PostVisibility = .public
    @State private var didLoadEmotionDraft = false
    @State private var intensity: Int = 5
    @State private var whatHelpedText: String = ""
    @State private var selectedHelpfulTags: Set<String> = []
    /// Single group when `visibility == .groups` (discoverable picker UX).
    @State private var selectedGroupId: String?

    private let emotionDefinitions: [String: String] = [
        "😊": "Feeling happy and content.",
        "😤": "Feeling frustrated or stressed.",
        "🥰": "Feeling loved or affectionate.",
        "💪": "Feeling strong or motivated.",
        "💭": "Feeling thoughtful or reflective.",
        "💫": "Feeling inspired or magical."
    ]

    // Get current week number
    private var weekNumber: Int {
        let calendar = Calendar.current
        return calendar.component(.weekOfYear, from: Date())
    }
    
    private var myHistoryEntries: [CheckInData] {
        firestore.wrapupHistoryEntries(forUserId: auth.currentUser?.id)
    }

    private var checkInData: CheckInData {
        let trimmedHelp = whatHelpedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return CheckInData(
            userName: userName,
            astrologySign: astrologySign,
            weekNumber: weekNumber,
            weeklyEmoji: weeklyEmoji,
            checkInImage: capturedImage,
            selectedEmotions: Set(emotionRouter.shareEmotions),
            emotionalInsight: emotionalInsight,
            gratitudeText: gratitudeText,
            whoopsText: whoopsText,
            poopsText: poopsText,
            lookForwardTo: lookForwardTo,
            profileImage: profileImage,
            checkInVideoURL: capturedVideoURL,
            visibility: visibility,
            intensity: intensity,
            whatHelped: trimmedHelp.isEmpty ? nil : trimmedHelp,
            helpfulTags: selectedHelpfulTags.isEmpty ? nil : selectedHelpfulTags.sorted(),
            sharedGroupIds: visibility == .groups ? selectedGroupId.map { [$0] } : nil,
            title: postTitle,
            selectedEmotionsOrdered: emotionRouter.shareEmotions
        )
    }

    private static let whatHelpedStorageKey = "whatHelpedByEmotion"

    private func whatHelpedHint(for emotions: Set<String>) -> String? {
        guard let key = EmotionRouter.preferredDisplayKey(in: emotions)?.lowercased(), !key.isEmpty else { return nil }
        let dict = UserDefaults.standard.dictionary(forKey: Self.whatHelpedStorageKey) as? [String: String] ?? [:]
        let hint = dict[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return hint.isEmpty ? nil : hint
    }

    /// Days from a high-intensity logged match to a calmer follow-up (retention / hope copy).
    private func daysToRecoverRetentionLine(for emotions: Set<String>) -> String? {
        guard let key = EmotionRouter.preferredDisplayKey(in: emotions)?.lowercased(), !key.isEmpty else { return nil }
        let sorted = myHistoryEntries.sorted { $0.date < $1.date }
        func matchesEmotion(_ entry: CheckInData) -> Bool {
            entry.selectedEmotions.contains { $0.lowercased() == key || $0.lowercased().contains(key) }
        }
        for i in 0..<sorted.count {
            guard matchesEmotion(sorted[i]), let hi = sorted[i].intensity, hi >= 7 else { continue }
            for j in (i + 1)..<sorted.count {
                guard matchesEmotion(sorted[j]), let lo = sorted[j].intensity, lo <= 4 else { continue }
                let days = Calendar.current.dateComponents([.day], from: sorted[i].date, to: sorted[j].date).day ?? 0
                guard days >= 1, days <= 21 else { continue }
                return "Last time you felt this, you got through it in \(days) day\(days == 1 ? "" : "s")."
            }
        }
        return nil
    }

    private func generateInsight(from text: String) -> String {
        let lower = text.lowercased()

        if lower.contains("stress") || lower.contains("overwhelmed") {
            return "It sounds like you're carrying a lot right now. Taking even a small pause could help reset your energy."
        }
        if lower.contains("happy") || lower.contains("good") {
            return "This seems like a positive moment—notice what contributed to it so you can recreate it."
        }
        if lower.contains("frustrated") || lower.contains("angry") {
            return "There may be something important to you that isn’t being met. That’s worth paying attention to."
        }

        return "You're taking a meaningful step by reflecting—keep exploring what this experience is telling you."
    }

    private static let draftEmotionsKey = "draftShareEmotions"
    private var isUITestMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest-mode")
    }

    private func saveDraftEmotions() {
        UserDefaults.standard.set(emotionRouter.shareEmotions.sorted(), forKey: Self.draftEmotionsKey)
    }

    private func loadDraftEmotionsIfNeeded() {
        guard !didLoadEmotionDraft else { return }
        didLoadEmotionDraft = true
        guard let arr = UserDefaults.standard.stringArray(forKey: Self.draftEmotionsKey), !arr.isEmpty else { return }
        emotionRouter.restoreShareDraft(from: arr)
    }

    private var visibilityFootnote: String {
        switch visibility {
        case .public: return "Public = visible in feed."
        case .friends: return "Friends = visible in feed."
        case .private: return "Private = only you."
        case .groups: return "Groups = only members of selected circles."
        }
    }

    private var groupShareSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Group")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.colors.textPrimary)
            if firestore.myGroups.isEmpty {
                Text("Create a group from Feed → Groups, then return here to choose it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Picker(
                    "Select Group",
                    selection: Binding(
                        get: { selectedGroupId ?? "" },
                        set: { selectedGroupId = $0.isEmpty ? nil : $0 }
                    )
                ) {
                    Text("Choose a group").tag("")
                    ForEach(firestore.myGroups) { group in
                        Text(group.name).tag(group.id)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(.top, 4)
    }

    var body: some View {
        VStack(spacing: 0) {
                // Fixed Header
                HStack(spacing: 12) {
                    ProfileImageView(image: profileImage, imageURL: URL(string: profileImageURL))
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.colors.sand.opacity(0.3), lineWidth: 1))
                        .shadow(color: AppTheme.colors.primary.opacity(0.1), radius: 2)
                        .onTapGesture {
                            if shareProfileNeedsBasicSetup {
                                showProfileCreation = true
                            }
                        }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: {
                            if shareProfileNeedsBasicSetup {
                                showProfileCreation = true
                            }
                        }) {
                            Text(userName.isEmpty ? "Welcome!" : userName)
                                .font(.headline)
                                .foregroundColor(AppTheme.colors.textPrimary)
                                .overlay(
                                    userName.isEmpty ?
                                    Rectangle()
                                        .fill(AppTheme.colors.textPrimary)
                                        .frame(height: 1)
                                        .offset(y: 2)
                                        .opacity(0.3) : nil,
                                    alignment: .bottom
                                )
                        }
                        Text("🔥 \(auth.currentUser?.checkInStreak ?? 0) day streak")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        if !astrologySign.isEmpty {
                            Text(astrologySign)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()

                    Menu {
                        if let uid = auth.currentUser?.id, !uid.isEmpty {
                            NavigationLink {
                                ProfileView(userId: uid, contextPost: nil)
                                    .environmentObject(firestore)
                                    .environmentObject(auth)
                            } label: {
                                Label("Edit profile", systemImage: "person.crop.circle")
                            }
                        }
                        NavigationLink {
                            HistoryView(entries: myHistoryEntries)
                        } label: {
                            Label("Past wrapups", systemImage: "clock.arrow.circlepath")
                        }
                        Button("Sign out", role: .destructive) {
                            Task {
                                await auth.signOut()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(AppTheme.colors.textPrimary.opacity(0.88))
                    }
                    .accessibilityIdentifier("share_profile_menu_button")

                    WeekNumberView(weekNumber: weekNumber, emoji: $weeklyEmoji)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.colors.background)
                        .shadow(color: AppTheme.colors.bark.opacity(0.05), radius: 8, y: 2)
                )
                .padding(.horizontal)
                
                // Scrollable Content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 32) {
                        // Camera section
                        SectionContainer(tint: AppTheme.colors.ocean.opacity(0.05)) {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Capture Your Moment", icon: "camera.fill", color: AppTheme.colors.ocean)
                                
                                MediaCaptureView(
                                    capturedImage: $capturedImage,
                                    capturedVideoURL: $capturedVideoURL,
                                    mediaError: $mediaError
                                )
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                if let mediaError {
                                    Text(mediaError)
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        
                        // Feeling wheel section
                        SectionContainer(tint: AppTheme.colors.moss.opacity(0.05)) {
                            VStack(spacing: 8) {
                                FeelingWheelView(
                                    selectedEmotions: Binding(
                                        get: { Set(emotionRouter.shareEmotions) },
                                        set: { newSet in
                                            let previous = emotionRouter.shareEmotions
                                            let keptInOrder = previous.filter { newSet.contains($0) }
                                            let added = newSet.subtracting(Set(previous))
                                            emotionRouter.updateShareSelection(keptInOrder + Array(added))
                                        }
                                    )
                                )
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(maxWidth: 500)
                                    .frame(minHeight: 480)
                                    .padding(.vertical, 12)

                                if let key = emotionRouter.lastSelectedEmotion
                                    ?? emotionRouter.shareEmotions.sorted().first, !key.isEmpty {
                                    let definition = emotionDefinitions[key]
                                        ?? LearnEmotionDefinitionLookup.definition(for: key)
                                    Text(definition)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                        .transition(.opacity)
                                        .animation(.easeInOut(duration: 0.2), value: emotionRouter.lastSelectedEmotion)
                                }

                                if !emotionRouter.shareEmotions.isEmpty {
                                    EmotionSummaryView(emotions: Set(emotionRouter.shareEmotions))
                                        .id("emotionSummary")
                                        .transition(.opacity)

                                    if let emotion = emotionRouter.lastSelectedEmotion
                                        ?? emotionRouter.shareEmotions.sorted().first {
                                        Text("Want to explore why you're feeling \(emotion)?")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .frame(maxWidth: .infinity)
                                            .padding(.horizontal, 8)
                                    }

                                    VStack(alignment: .leading, spacing: 10) {
                                        if let hint = whatHelpedHint(for: Set(emotionRouter.shareEmotions)) {
                                            Text("Last time you felt this, you said this helped: \(hint)")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.colors.pine)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }

                                        if let retention = daysToRecoverRetentionLine(for: Set(emotionRouter.shareEmotions)) {
                                            Text(retention)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.colors.ocean)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }

                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Intensity")
                                                .font(.headline)
                                                .foregroundStyle(AppTheme.colors.textPrimary)

                                            Slider(
                                                value: Binding(
                                                    get: { Double(intensity) },
                                                    set: { intensity = Int($0) }
                                                ),
                                                in: 1...10,
                                                step: 1
                                            )
                                            Text("\(intensity)/10")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        WhatHelpedInputView(
                                            selectedTags: $selectedHelpfulTags,
                                            detailText: $whatHelpedText
                                        )
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .onChange(of: emotionRouter.shareEmotions) {
                                saveDraftEmotions()
                                withAnimation {
                                    proxy.scrollTo("emotionSummary", anchor: .center)
                                }
                            }
                        }
                        
                        // Input sections
                        SectionContainer(tint: AppTheme.colors.sage.opacity(0.06)) {
                            VStack(spacing: 28) {
                                SectionHeader(title: "Your Reflections", icon: "pencil.line", color: AppTheme.colors.bark)

                                reflectionCard {
                                    InsightInputView(text: $emotionalInsight)
                                }

                                if !emotionalInsight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    reflectionCard {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Label("Insight", systemImage: "sparkles")
                                                .font(.headline)
                                                .foregroundColor(AppTheme.colors.textPrimary)
                                            Text(generateInsight(from: emotionalInsight))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }

                                reflectionCard {
                                    GratitudeInputView(text: $gratitudeText)
                                }

                                HStack(alignment: .top, spacing: 16) {
                                    reflectionCard {
                                        WhoopsInputView(text: $whoopsText)
                                    }
                                    reflectionCard {
                                        PoopsInputView(text: $poopsText)
                                    }
                                }

                                reflectionCard {
                                    LookForwardInputView(text: $lookForwardTo)
                                }

                                reflectionCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("Post title", systemImage: "textformat")
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.colors.textPrimary)
                                        TextField("Give your post a title...", text: $postTitle)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }

                                reflectionCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Label("Share to", systemImage: "lock.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(AppTheme.colors.textPrimary)
                                        Picker("Share to", selection: $visibility) {
                                            Text("Public").tag(PostVisibility.public)
                                            Text("Friends").tag(PostVisibility.friends)
                                            Text("Group").tag(PostVisibility.groups)
                                            Text("Only me").tag(PostVisibility.private)
                                        }
                                        .pickerStyle(.segmented)
                                        Text(visibilityFootnote)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)

                                        if visibility == .groups {
                                            groupShareSection
                                        }
                                    }
                                }
                            }
                        }
                        }
                    }
                }
                .background(AppTheme.colors.secondaryBackground)

                // Footer
                FooterView(checkInData: checkInData)
        }
        .background(AppTheme.colors.secondaryBackground)
        .sheet(isPresented: $showProfileCreation) {
            ProfileCreationView(isPresented: $showProfileCreation,
                              userName: $userName,
                              profileImage: $profileImage,
                              selectedUIImage: $profileUIImage,
                              astrologySign: $astrologySign) {
                await persistProfileOnboardingIfNeeded()
            }
        }
        .onAppear {
            loadDraftEmotionsIfNeeded()
            Task { await refreshProfilePresentationState() }
            if isUITestMode, weeklyEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                weeklyEmoji = "✨"
                if emotionalInsight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    emotionalInsight = "UI test check-in"
                }
            }
        }
        .onChange(of: auth.currentUser?.id) { _, _ in
            Task { await refreshProfilePresentationState() }
        }
        .onChange(of: visibility) { _, newVal in
            if newVal == .groups, selectedGroupId == nil, let first = firestore.myGroups.first {
                selectedGroupId = first.id
            }
        }
        .onReceive(firestore.$myGroups) { groups in
            guard visibility == .groups else { return }
            if let id = selectedGroupId, !groups.contains(where: { $0.id == id }) {
                selectedGroupId = groups.first?.id
            }
        }
    }

    private func refreshProfilePresentationState() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run { showProfileCreation = false }
            return
        }
        let profile = await firestore.fetchUserProfile(userId: uid)
        let appProfile = await firestore.fetchAppUserProfile(userId: uid)
        let rootName = appProfile?.name ?? auth.currentUser?.name ?? ""
        let resolvedName = (profile?.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? profile?.name ?? rootName
            : rootName
        let resolvedZodiac = profile?.zodiacSign
            ?? appProfile?.zodiacSign
            ?? auth.currentUser?.zodiacSign
            ?? ""
        let profileImageURL = profile?.profileImageURL
            ?? appProfile?.profileImageURL
            ?? auth.currentUser?.profileImageURL
            ?? ""
        let gate = ProfileSetupGate.evaluate(profile: profile, appUser: appProfile ?? auth.currentUser)
        let imageDisplayed = !profileImageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || profileUIImage != nil

        #if DEBUG
        print("[PROFILE_SETUP_GATE] uid=\(uid) displayName=\(resolvedName) zodiacSign=\(resolvedZodiac) profileImageURL=\(profileImageURL) hasProfileImage=\(gate.hasDurableProfileImage) profileComplete=\(!gate.needsBasicSetup) sourcePath=users+profile/main")
        print("[SHARE_PROFILE_RESOLVE] uid=\(uid) displayName=\(resolvedName) zodiacSign=\(resolvedZodiac) hasProfileImage=\(gate.hasDurableProfileImage) profileImageURL=\(profileImageURL) sourcePath=users+profile/main imageDisplayed=\(imageDisplayed) onboardingTriggered=\(gate.needsBasicSetup) reason=\(gate.reason)")
        #endif

        await MainActor.run {
            userName = resolvedName
            astrologySign = resolvedZodiac
            self.profileImageURL = profileImageURL
            shareProfileNeedsBasicSetup = gate.needsBasicSetup
            showProfileCreation = gate.needsBasicSetup
        }
    }

    private func persistProfileOnboardingIfNeeded() async {
        guard let uid = auth.currentUser?.id else { return }
        let cleanName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanZodiac = astrologySign.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanZodiac.isEmpty else { return }
        do {
            try await firestore.saveOnboardingProfile(
                userId: uid,
                displayName: cleanName,
                zodiacSign: cleanZodiac,
                profileImage: profileUIImage,
                hasProfileImage: profileUIImage != nil || !profileImageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            await auth.refreshCurrentUserProfile()
            ProfileManager.shared.invalidate(userId: uid)
            await refreshProfilePresentationState()
        } catch {
            AppLogger.error("persistProfileOnboardingIfNeeded failed: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private func reflectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.colors.secondaryBackground.opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
    }
}

// Helper Views
struct SectionContainer<Content: View>: View {
    let tint: Color
    let content: Content

    init(tint: Color = .clear, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(tint)
                    )
                    .shadow(color: AppTheme.colors.bark.opacity(0.06), radius: 10, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
            .padding(.horizontal, 16)
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 18, weight: .semibold))
                .frame(minWidth: 24)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.colors.textPrimary)
        }
        .frame(height: 44)
    }
}

#if DEBUG
#Preview("Home (mock)") {
    ContentViewPreviewHost()
}

private struct ContentViewPreviewHost: View {
    @StateObject private var auth = AuthManager(previewLoggedIn: true, previewUser: PreviewSampleData.currentUser)
    @StateObject private var tabRouter = TabRouter()
    @StateObject private var feedViewModel = FeedViewModel()
    @StateObject private var emotionRouter = EmotionRouter()
    private let firestore = FirestoreManager.shared

    var body: some View {
        ContentView()
            .environmentObject(auth)
            .environmentObject(firestore)
            .environmentObject(tabRouter)
            .environmentObject(feedViewModel)
            .environmentObject(emotionRouter)
            .onAppear {
                firestore.applyPreviewPosts(SeedDataManager.previewSeedPosts())
            }
    }
}
#endif

