import SwiftUI
import MessageUI
import Social

// Main Share Options View
struct ShareOptionsView: View {
    @Binding var isShowing: Bool
    let checkInData: CheckInData
    @StateObject private var mailDelegate = MailDelegate()
    
    private let appInviteText = """
    🌟 Join me on Weekday Wrapup! 🌟
    
    It's a beautiful app that helps you track your emotional journey, celebrate small wins, and grow through self-reflection.
    
    Download Weekday Wrapup:
    [App Store Link]
    
    Let's share our journeys together! ✨
    """
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Share to")) {
                    ShareOptionRow(title: "Facebook", icon: "facebook", color: .blue) {
                        shareToFacebook()
                    }
                    
                    ShareOptionRow(title: "X (Twitter)", icon: "x.circle", color: .black) {
                        shareToX()
                    }
                    
                    ShareOptionRow(title: "Email", icon: "envelope.fill", color: .gray) {
                        shareViaEmail()
                    }
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { isShowing = false }
                }
            }
        }
    }
    
    // Sharing methods...
    private func shareToFacebook() {
        // ... existing implementation ...
    }
    
    private func shareToX() {
        // ... existing implementation ...
    }
    
    private func shareViaEmail() {
        // ... existing implementation ...
    }
    
    // PDF generation methods...
    private func generatePDF() -> Data? {
        let pageSize = CGSize(width: 612, height: 792) // US Letter size
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        
        let data = renderer.pdfData { context in
            context.beginPage()
            // PDF generation code...
        }
        
        return data
    }
    
    private func savePDFToTemporaryDirectory(_ pdfData: Data) -> URL? {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
        let fileURL = tempDirectoryURL.appendingPathComponent("weekly-wrapup.pdf")
        
        do {
            try pdfData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving PDF: \(error)")
            return nil
        }
    }
}

// Helper Views and Classes
class MailDelegate: NSObject, ObservableObject, MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController,
                             didFinishWith result: MFMailComposeResult,
                             error: Error?) {
        controller.dismiss(animated: true)
    }
}

struct ComposeMailController: UIViewControllerRepresentable {
    let emailBody: String
    let subject: String
    let pdfData: Data
    let delegate: MailDelegate
    let completion: () -> Void
    
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

// Move PDF helpers here
private func drawLogo(in rect: CGRect) {
    // ... existing implementation ...
}

private func drawBox(in rect: CGRect, title: String, content: String, style: [NSAttributedString.Key: Any]) {
    // ... existing implementation ...
} 