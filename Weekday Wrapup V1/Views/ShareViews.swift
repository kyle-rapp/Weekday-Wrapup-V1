import SwiftUI
import MessageUI
import Social
import UIKit

// Main Share Options View
struct ShareOptionsView: View {
    @Binding var isShowing: Bool
    let checkInData: CheckInData
    @StateObject private var mailDelegate = MailDelegate()
    @ObservedObject private var feedStore = FeedPostsStore.shared

    @State private var showMailComposer = false
    @State private var mailPDFData: Data?

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
                        feedStore.addFromCheckIn(checkInData)
                        isShowing = false
                    }
                }
            }
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
