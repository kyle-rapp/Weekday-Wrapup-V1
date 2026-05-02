import SwiftUI

/// FILE: Views/PreferencesOnboardingView.swift
/// Multi-step personalization saved to `users/{uid}/preferences/profile`.

struct PreferencesOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    @State private var step = 0
    private let totalSteps = 4

    // Step 0 — immediate check-in
    @State private var currentEmotion = "Sad"
    @State private var currentIntensity = 5.0
    private let immediateEmotionOptions = ["Sad", "Angry", "Scared", "Joyful", "Peaceful", "Powerful"]

    // Step 1 — what helps (2-3 taps)
    @State private var enjoysWalking = false
    @State private var journals = false
    @State private var meditates = false
    @State private var callsFriends = false
    @State private var enjoysMusic = false

    // Step 1 — joy (max 5)
    private let joyOptions = ["Walking", "Music", "Friends", "Nature", "Cooking", "Reading", "Sports", "Games", "Art", "Learning"]
    @State private var selectedJoy: Set<String> = []

    // Step 2 — stressors (max 5)
    private let stressOptions = ["Work", "Money", "Health", "Family", "Relationships", "Time", "Sleep", "Social media", "News", "Uncertainty"]
    @State private var selectedStress: Set<String> = []

    // Step 3 — optional
    @State private var pronouns = ""
    @State private var relationshipStatus = ""
    @State private var favoriteSong = ""
    @State private var favoriteArtist = ""
    @State private var hasPet = false
    @State private var drinksAlcohol: Bool?
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                    .padding(.horizontal)
                    .padding(.top, 8)

                Group {
                    switch step {
                    case 0: stepImmediateCheckIn
                    case 1: stepWhatHelps
                    case 2: stepValueNow
                    default: stepOptional
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
                    .padding()
            }
            .background(AppTheme.colors.secondaryBackground.ignoresSafeArea())
            .navigationTitle("Personalize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Couldn’t save", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(AppTheme.colors.ocean)
            Text(stepTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.colors.textSecondary)
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Step 1: Quick check-in"
        case 1: return "Step 2: What usually helps? (2–3 taps)"
        case 2: return "Step 3: Here’s something for right now"
        default: return "Step 4: Optional deeper profile"
        }
    }

    private var stepImmediateCheckIn: some View {
        Form {
            Section("How do you feel right now?") {
                Picker("Emotion", selection: $currentEmotion) {
                    ForEach(immediateEmotionOptions, id: \.self) { item in
                        Text(item).tag(item)
                    }
                }
            }
            Section("Intensity") {
                Slider(value: $currentIntensity, in: 1...10, step: 1)
                Text("\(Int(currentIntensity))/10")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var stepWhatHelps: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                helpToggle("Walking", "figure.walk", $enjoysWalking)
                helpToggle("Music", "music.note", $enjoysMusic)
                helpToggle("Journaling", "book.pages", $journals)
                helpToggle("Calling someone", "phone", $callsFriends)
                helpToggle("Meditation / breath", "wind", $meditates)
                Text("Choose 2-3 for now. You can edit later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding()
        }
    }

    private func helpToggle(_ title: String, _ icon: String, _ on: Binding<Bool>) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if on.wrappedValue {
                on.wrappedValue = false
            } else if selectedHelpCount < 3 {
                on.wrappedValue = true
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(AppTheme.colors.ocean)
                    .frame(width: 36)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.colors.textPrimary)
                Spacer()
                Image(systemName: on.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on.wrappedValue ? AppTheme.colors.pine : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.colors.background)
            )
        }
        .buttonStyle(.plain)
    }

    private var stepValueNow: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Here’s something that might help right now")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.colors.textPrimary)
            Text(quickActionHint)
                .font(.body)
                .foregroundStyle(AppTheme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.colors.background)
                )
            Spacer(minLength: 0)
        }
        .padding()
    }

    private var stepJoy: some View {
        ScrollView {
            FlowLayout(spacing: 10) {
                ForEach(joyOptions, id: \.self) { option in
                    joyChip(option)
                }
            }
            .padding()
        }
    }

    private func joyChip(_ option: String) -> some View {
        let on = selectedJoy.contains(option)
        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if on {
                selectedJoy.remove(option)
            } else if selectedJoy.count < 5 {
                selectedJoy.insert(option)
            }
        } label: {
            Text(option)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(on ? AppTheme.colors.pine.opacity(0.35) : AppTheme.colors.background)
                )
                .overlay(Capsule().stroke(on ? AppTheme.colors.pine : Color.primary.opacity(0.08), lineWidth: 1))
                .foregroundStyle(AppTheme.colors.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private var stepStress: some View {
        ScrollView {
            FlowLayout(spacing: 10) {
                ForEach(stressOptions, id: \.self) { option in
                    stressChip(option)
                }
            }
            .padding()
        }
    }

    private func stressChip(_ option: String) -> some View {
        let on = selectedStress.contains(option)
        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if on {
                selectedStress.remove(option)
            } else if selectedStress.count < 5 {
                selectedStress.insert(option)
            }
        } label: {
            Text(option)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(on ? Color.orange.opacity(0.22) : AppTheme.colors.background)
                )
                .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .foregroundStyle(AppTheme.colors.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private var stepOptional: some View {
        Form {
            Section("Music") {
                TextField("Favorite song right now", text: $favoriteSong)
                TextField("Artist (optional)", text: $favoriteArtist)
            }
            Section("Pronouns") {
                TextField("e.g. they/them", text: $pronouns)
            }
            Section("Relationship (optional)") {
                TextField("Single, partnered…", text: $relationshipStatus)
            }
            Section {
                Toggle("I have a pet", isOn: $hasPet)
            }
            Section("Alcohol") {
                Picker("Drinks alcohol", selection: Binding(
                    get: { drinksAlcohol.map { $0 ? 1 : 0 } ?? 2 },
                    set: { v in
                        if v == 2 { drinksAlcohol = nil }
                        else { drinksAlcohol = v == 1 }
                    }
                )) {
                    Text("Prefer not to say").tag(2)
                    Text("No").tag(0)
                    Text("Yes").tag(1)
                }
                .pickerStyle(.segmented)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var bottomBar: some View {
        HStack {
            if step > 0 {
                Button("Back") { withAnimation { step -= 1 } }
                    .font(.body.weight(.semibold))
            }
            Spacer()
            if step < totalSteps - 1 {
                Button("Next") { withAnimation { step += 1 } }
                    .font(.body.weight(.semibold))
                    .disabled(!canAdvanceFromCurrentStep)
            } else {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save & finish")
                            .font(.body.weight(.semibold))
                    }
                }
                .disabled(isSaving)
            }
        }
    }

    private var canAdvanceFromCurrentStep: Bool {
        switch step {
        case 1: return selectedHelpCount >= 1
        default: return true
        }
    }

    private var selectedHelpCount: Int {
        [enjoysWalking, journals, meditates, callsFriends, enjoysMusic].filter { $0 }.count
    }

    private var quickActionHint: String {
        let e = currentEmotion.lowercased()
        let tough = ["sad", "angry", "scared"].contains { e.contains($0) }
        if tough {
            if meditates { return "Try one round of box breathing, then name this emotion in one sentence." }
            if callsFriends { return "Send one low-pressure text to someone safe, then ask what you need right now." }
            return "Start with grounding: name 5 things you can see, then ask what you need right now."
        }
        if journals {
            return "Write what caused this feeling and one thing you want to repeat intentionally."
        }
        return "Capture what helped today so you can repeat it when this emotion comes back."
    }

    private func buildPreferences() -> UserPreferences {
        var creative: [String] = []
        if enjoysMusic { creative.append("music") }
        let rel = relationshipStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        return UserPreferences(
            enjoysWalking: enjoysWalking ? true : nil,
            hasPet: hasPet ? true : nil,
            journals: journals ? true : nil,
            meditates: meditates ? true : nil,
            callsFriends: callsFriends ? true : nil,
            creativeOutlets: creative.isEmpty ? nil : creative,
            drinksAlcohol: drinksAlcohol,
            relationshipStatus: rel.isEmpty ? nil : rel,
            pronouns: pronouns.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : pronouns.trimmingCharacters(in: .whitespacesAndNewlines),
            topJoyActivities: Array(selectedJoy).sorted(),
            topStressors: Array(selectedStress).sorted(),
            preferredCopingStyles: inferredCopingStyles()
        )
    }

    private func inferredCopingStyles() -> [String]? {
        var styles: [String] = []
        if journals || meditates { styles.append("alone") }
        if callsFriends { styles.append("social") }
        if enjoysWalking { styles.append("movement") }
        return styles.isEmpty ? nil : styles
    }

    private func save() async {
        guard let uid = auth.currentUser?.id else { return }
        isSaving = true
        defer { isSaving = false }
        let prefs = buildPreferences()
        do {
            try await firestore.saveUserPreferences(prefs, userId: uid)
            let songTrim = favoriteSong.trimmingCharacters(in: .whitespacesAndNewlines)
            let artistTrim = favoriteArtist.trimmingCharacters(in: .whitespacesAndNewlines)
            if !songTrim.isEmpty || !artistTrim.isEmpty {
                var profile = await firestore.fetchUserProfile(userId: uid)
                    ?? UserProfile(name: auth.currentUser?.name ?? "Member")
                if !songTrim.isEmpty { profile.favoriteSong = songTrim }
                if !artistTrim.isEmpty { profile.favoriteArtist = artistTrim }
                try await firestore.saveUserProfile(profile, userId: uid)
            }
            UserDefaults.standard.set(true, forKey: Self.completedKey)
            await MainActor.run { dismiss() }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private static let completedKey = "preferencesOnboardingCompleted"
    static let autoPromptKey = "preferencesGrowAutoPromptShown"

    static var hasCompletedPreferencesProfile: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }
}

#if DEBUG
#Preview {
    PreferencesOnboardingView()
        .environmentObject(FirestoreManager.shared)
        .environmentObject(AuthManager(previewLoggedIn: true, previewUser: PreviewSampleData.currentUser))
}
#endif
