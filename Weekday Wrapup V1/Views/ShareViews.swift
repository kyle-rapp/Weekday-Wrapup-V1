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

    @State private var showMailComposer = false
    @State private var mailPDFData: Data?
    @State private var feedError: String?
    @State private var isPostingToFeed = false
    @State private var showFeedAlert = false
    @State private var feedAlertText = ""

    private var canSubmitFeedPost: Bool {
        let insight = checkInData.emotionalInsight.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = checkInData.weeklyEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let whoops = checkInData.whoopsText.trimmingCharacters(in: .whitespacesAndNewlines)
        let weekly = checkInData.weeklyGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        let monthly = checkInData.monthlyGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        return !emoji.isEmpty || !insight.isEmpty || !whoops.isEmpty || !weekly.isEmpty || !monthly.isEmpty
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
                    ShareOptionRow(title: "Feed", icon: "list.bullet", color: .green) {
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
                    subject: "My Weekday Wrapup",
                    pdfData: pdfData,
                    delegate: mailDelegate
                )
            }
        }
    }

    private func postToFeed() {
        feedError = nil
        firestore.clearErrorMessage()

        guard let firebaseUser = Auth.auth().currentUser else {
            print("❌ No authenticated user")
            feedError = "You must be signed in to post."
            feedAlertText = feedError ?? ""
            showFeedAlert = true
            return
        }

        guard let uid = auth.currentUser?.id,
              let name = auth.currentUser?.name,
              uid == firebaseUser.uid else {
            print("❌ Auth profile missing or mismatch")
            feedError = "You must be signed in to post."
            feedAlertText = feedError ?? ""
            showFeedAlert = true
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            print("❌ Empty profile name")
            feedError = "Add your name in profile before posting to the feed."
            feedAlertText = feedError ?? ""
            showFeedAlert = true
            return
        }

        guard canSubmitFeedPost else {
            feedError = "Add an emoji, insight, whoops, or a goal before posting."
            feedAlertText = feedError ?? ""
            showFeedAlert = true
            return
        }

        Task { @MainActor in
            isPostingToFeed = true
            defer { isPostingToFeed = false }

            let allowed = await firestore.canCreatePost(userId: uid)
            guard allowed else {
                let msg = "You've reached your 3 posts for today 🌿"
                print("🚫", msg)
                feedError = msg
                feedAlertText = msg
                showFeedAlert = true
                return
            }

            let ok = await firestore.createPost(from: checkInData, authorId: uid, authorName: trimmedName)
            if ok {
                isShowing = false
                feedError = nil
                tabRouter.completePostToFeedFlow()
            } else {
                let msg = firestore.errorMessage ?? "Could not post to the feed."
                print("❌ Firestore error:", msg)
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
    }
}
