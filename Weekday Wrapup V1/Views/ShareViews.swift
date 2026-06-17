import SwiftUI
import MessageUI
import UIKit
import FirebaseAuth

// Main Share Options View
struct ShareOptionsView: View {
    @Binding var isShowing: Bool
    let checkInData: CheckInData
    @StateObject private var mailDelegate = MailDelegate()
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var tabRouter: TabRouter
    @EnvironmentObject private var emotionRouter: EmotionRouter

    @State private var showMailComposer = false
    @State private var mailPDFData: Data?
    @State private var feedError: String?
    @State private var isPostingToFeed = false
    @State private var showFeedAlert = false
    @State private var feedAlertText = ""
    @State private var hideReactions = false
    @State private var hideComments = false

    private var canSubmitFeedPost: Bool {
        let insight = checkInData.emotionalInsight.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = checkInData.weeklyEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let whoops = checkInData.whoopsText.trimmingCharacters(in: .whitespacesAndNewlines)
        let weekly = checkInData.weeklyGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        let monthly = checkInData.monthlyGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        let gratitude = checkInData.gratitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lookForward = checkInData.lookForwardTo.trimmingCharacters(in: .whitespacesAndNewlines)
        return !emoji.isEmpty || !insight.isEmpty || !whoops.isEmpty
            || !weekly.isEmpty || !monthly.isEmpty || !gratitude.isEmpty || !lookForward.isEmpty
    }

    private var hasNonEmptyProfileName: Bool {
        guard let raw = auth.currentUser?.name else { return false }
        return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var feedActionEnabled: Bool {
        Auth.auth().currentUser != nil
            && auth.currentUser != nil
            && hasNonEmptyProfileName
            && canSubmitFeedPost
            && !isPostingToFeed
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Share")
                    .font(.headline)
                Spacer()
                Button("Cancel") { isShowing = false }
                    .font(.body)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            List {
                Section(header: Text("Post privacy")) {
                    Toggle("Hide reaction counts from others", isOn: $hideReactions)
                        .font(.subheadline)
                    Toggle("Disable comments", isOn: $hideComments)
                        .font(.subheadline)
                }

                Section(header: Text("Share to")) {
                    ShareOptionRow(title: "Facebook", icon: "link.circle.fill", color: .blue) {
                        shareToFacebook()
                    }
                    ShareOptionRow(title: "X (Twitter)", icon: "x.circle.fill", color: .black) {
                        shareToX()
                    }
                    ShareOptionRow(title: "Email", icon: "envelope.fill", color: .gray) {
                        shareViaEmail()
                    }
                    ShareOptionRow(title: "Feed", icon: "list.bullet", color: .green, accessibilityId: "submit_post_button") {
                        postToFeed()
                    }
                    .disabled(!feedActionEnabled)
                }
            }
            if let feedError, !feedError.isEmpty {
                Text(feedError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .alert("Feed", isPresented: $showFeedAlert) {
            Button("OK", role: .cancel) {
                showFeedAlert = false
            }
        } message: {
            Text(feedAlertText)
        }
        .sheet(isPresented: $showMailComposer, onDismiss: {
            mailPDFData = nil
        }) {
            if let pdfData = mailPDFData {
                ComposeMailController(
                    emailBody: "Here's my weekly wrap-up!",
                    subject: "My SO: Share Openly check-in",
                    pdfData: pdfData,
                    delegate: mailDelegate
                )
            }
        }
    }

    private func postToFeed() {
        print("[POST] Attempting post submit from share sheet")
        feedError = nil
        firestore.clearErrorMessage()

        guard let firebaseUser = Auth.auth().currentUser else {
            print("[ERROR] No authenticated user for post submit")
            feedError = "You must be signed in to post."
            feedAlertText = feedError ?? ""
            showFeedAlert = true
            return
        }

        guard let uid = auth.currentUser?.id,
              let name = auth.currentUser?.name,
              uid == firebaseUser.uid else {
            print("[ERROR] Auth profile missing or mismatch for post submit")
            feedError = "You must be signed in to post."
            feedAlertText = feedError ?? ""
            showFeedAlert = true
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            print("[ERROR] Empty profile name blocked post submit")
            feedError = "Add your name in profile before posting to the feed."
            feedAlertText = feedError ?? ""
            showFeedAlert = true
            return
        }

        guard canSubmitFeedPost else {
            feedError = "Add an emoji, insight, whoops, gratitude, or something you're looking forward to before posting."
            feedAlertText = feedError ?? ""
            showFeedAlert = true
            return
        }

        Task { @MainActor in
            isPostingToFeed = true
            defer { isPostingToFeed = false }
            let previousEntries = firestore.wrapupHistoryEntries(forUserId: uid)

            let allowed = await firestore.canCreatePost(userId: uid)
            guard allowed else {
                let msg = "You've reached your 3 posts for today 🌿"
                print("[POST] Blocked by daily post limit")
                feedError = msg
                feedAlertText = msg
                showFeedAlert = true
                return
            }

            let tip = checkInData.whatHelped ?? ""
            let extractedTags = HelpfulTagger.extractTags(from: tip)
            var privacyCheckIn = checkInData
            privacyCheckIn.hideReactions = hideReactions
            privacyCheckIn.hideComments = hideComments
            let ok = await firestore.createPost(
                from: privacyCheckIn,
                authorId: uid,
                authorName: trimmedName,
                helpfulTags: extractedTags
            )
            if ok {
                print("[POST] Post creation succeeded")
                let trimmedTip = tip.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedTip.isEmpty,
                   let key = EmotionRouter.preferredDisplayKey(in: checkInData.selectedEmotions)?.lowercased(),
                   !key.isEmpty {
                    var dict = UserDefaults.standard.dictionary(forKey: "whatHelpedByEmotion") as? [String: String] ?? [:]
                    dict[key] = trimmedTip
                    UserDefaults.standard.set(dict, forKey: "whatHelpedByEmotion")
                }
                emotionRouter.saveEntry()
                UserDefaults.standard.removeObject(forKey: "draftShareEmotions")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                await auth.recordSuccessfulWrapupPost()
                let eventStream = EmotionalEventStreamService(firestore: firestore)
                let beforeSnapshot: EmotionSnapshot? = {
                    guard let previous = previousEntries.sorted(by: { $0.date > $1.date }).first else { return nil }
                    return EmotionSnapshot(
                        emotion: previous.firstSelectedEmotionLabel,
                        intensity: Double(previous.intensity ?? 5)
                    )
                }()
                let afterSnapshot = EmotionSnapshot(
                    emotion: checkInData.firstSelectedEmotionLabel,
                    intensity: Double(checkInData.intensity ?? 5)
                )
                await eventStream.logEmotionCheckIn(
                    userId: uid,
                    source: .checkInPopup,
                    emotionBefore: beforeSnapshot,
                    emotionAfter: afterSnapshot,
                    tags: checkInData.helpfulTags ?? [],
                    metadata: [
                        "flow": "share_post",
                        "visibility": checkInData.visibility.rawValue
                    ]
                )
                let prefs = await firestore.fetchUserPreferences(userId: uid)
                let reflectionTags = await firestore.fetchPositiveReflectionTags(userId: uid)
                let combinedText = [
                    checkInData.emotionalInsight,
                    checkInData.gratitudeText,
                    checkInData.whoopsText,
                    checkInData.lookForwardTo,
                    checkInData.weeklyGoal,
                    checkInData.monthlyGoal
                ]
                .joined(separator: " ")
                let intensity = checkInData.intensity ?? 5
                let context = EmotionContext(
                    emotion: checkInData.firstSelectedEmotionLabel,
                    intensity: intensity,
                    journalText: combinedText,
                    helpfulTags: Array(Set((checkInData.helpfulTags ?? []) + extractedTags + reflectionTags)).sorted(),
                    userPreferences: prefs,
                    history: firestore.wrapupHistoryEntries(forUserId: uid),
                    weather: .neutral,
                    stressors: prefs?.topStressors ?? []
                )
                let personalization = EmotionPersonalizationEngine()
                let bundle = personalization.buildCheckInBundle(context: context)
                isShowing = false
                feedError = nil
                tabRouter.completePostToFeedFlow()
                // Only show for negative emotions (always) or positive emotions with intensity ≥ 5
                let polarity = personalization.emotionPolarity(for: checkInData.firstSelectedEmotionLabel)
                let shouldShowPopup = polarity == .negative || polarity == .unknown || intensity >= 5
                if shouldShowPopup {
                    tabRouter.presentDailyRecommendations(bundle)
                }
            } else {
                let msg = firestore.errorMessage ?? "Could not post to the feed."
                print("[ERROR] Firestore post create failed: \(msg)")
                feedError = msg
                feedAlertText = msg
                showFeedAlert = true
            }
        }
    }

    // MARK: - Sharing Methods

    private func shareViaEmail() {
        guard MFMailComposeViewController.canSendMail() else {
            print("Mail not configured")
            return
        }
        guard let data = PDFGenerator.generate(checkInData: checkInData) else { return }
        mailDelegate.onFinish = {
            showMailComposer = false
        }
        mailPDFData = data
        showMailComposer = true
    }

    private func shareToFacebook() {
        shareWithActivitySheet()
    }

    private func shareToX() {
        shareWithActivitySheet()
    }

    private func shareWithActivitySheet() {
        guard let pdfData = PDFGenerator.generate(checkInData: checkInData),
              let tempURL = PDFGenerator.writeToTemporaryFile(data: pdfData) else { return }
        var items: [Any] = [checkInData.shareText, tempURL]
        if let image = checkInData.checkInImage {
            items.insert(image, at: 1)
        }
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        present(vc: activityVC)
    }

    private func present(vc: UIViewController) {
        guard let root = topViewController() else { return }
        root.present(vc, animated: true)
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }

    private func topViewController(from base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? rootViewController()
        if let nav = base as? UINavigationController, let visible = nav.visibleViewController {
            return topViewController(from: visible)
        }
        if let presented = base?.presentedViewController {
            return topViewController(from: presented)
        }
        return base
    }
}

// Helper Views and Classes
class MailDelegate: NSObject, ObservableObject, MFMailComposeViewControllerDelegate {
    var onFinish: (() -> Void)?

    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        controller.dismiss(animated: true)
        onFinish?()
        onFinish = nil
    }
}

struct ComposeMailController: UIViewControllerRepresentable {
    let emailBody: String
    let subject: String
    let pdfData: Data
    let delegate: MailDelegate

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = delegate
        composer.setSubject(subject)
        composer.setMessageBody(emailBody, isHTML: false)
        composer.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: "weekly-wrapup.pdf")
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

struct ShareOptionRow: View {
    let title: String
    let icon: String
    let color: Color
    var accessibilityId: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .foregroundColor(.primary)
            }
        }
        .accessibilityIdentifier(
            accessibilityId
            ?? "share_option_\(title.lowercased().replacingOccurrences(of: " ", with: "_"))"
        )
    }
}
