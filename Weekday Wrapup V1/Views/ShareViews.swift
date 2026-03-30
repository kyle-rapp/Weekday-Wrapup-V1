import SwiftUI
import MessageUI
import Social
import UIKit
import AVKit

// Main Share Options View
struct ShareOptionsView: View {
    @Binding var isShowing: Bool
    let checkInData: CheckInData
    @StateObject private var mailDelegate = MailDelegate()
    @ObservedObject var feed = FeedManager.shared

    private let appInviteText = """
    🌟 Join me on Weekday Wrapup! 🌟
    Download Weekday Wrapup: [App Store Link]
    Let's share our journeys together! ✨
    """

    var body: some View {
        NavigationView {
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
                        feed.add(checkInData)
                        isShowing = false
                    }
                }
            }
            .navigationTitle("Share")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { isShowing = false }
                }
            }
        }
    }
    
    // MARK: - Sharing Methods
    
    private func shareViaEmail() {
        guard MFMailComposeViewController.canSendMail() else { return }
        guard let pdfData = PDFGenerator.generate(checkInData: checkInData) else { return }

        let mailVC = MFMailComposeViewController()
        mailVC.mailComposeDelegate = mailDelegate
        mailVC.setSubject("My Weekly Wrapup")
        mailVC.setMessageBody(appInviteText, isHTML: false)
        mailVC.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: "weekly-wrapup.pdf")

        present(vc: mailVC)
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

// MARK: - Feed Manager Singleton
class FeedManager: ObservableObject {
    static let shared = FeedManager()
    @Published var posts: [CheckInData] = FeedManager.dummyFeedPosts

    func add(_ checkIn: CheckInData) {
        posts.insert(checkIn, at: 0)
    }

    static let dummyFeedPosts: [CheckInData] = [
        CheckInData(
            userName: "Alice",
            astrologySign: "♈︎ Aries",
            weekNumber: 3,
            weeklyEmoji: "😊",
            checkInImage: UIImage(systemName: "person.fill"),
            selectedEmotions: Set(["😊", "💪"]),
            emotionalInsight: "I felt productive and happy.",
            whoopsText: "Skipped gym once.",
            poopsText: "Ate too much sugar.",
            weeklyGoal: "Finish reading a book",
            monthlyGoal: "Run 10 miles"
        ),
        CheckInData(
            userName: "Bob",
            astrologySign: "♉︎ Taurus",
            weekNumber: 3,
            weeklyEmoji: "😤",
            checkInImage: UIImage(systemName: "person.fill"),
            selectedEmotions: Set(["😤", "💭"]),
            emotionalInsight: "Frustrated but reflective.",
            whoopsText: "Missed a deadline.",
            poopsText: "Over-caffeinated.",
            weeklyGoal: "Organize workspace",
            monthlyGoal: "Meditate 10x"
        ),
        CheckInData(
            userName: "Clara",
            astrologySign: "♊︎ Gemini",
            weekNumber: 3,
            weeklyEmoji: "🥰",
            checkInImage: UIImage(systemName: "person.fill"),
            selectedEmotions: Set(["🥰", "💫"]),
            emotionalInsight: "Loved spending time with friends.",
            whoopsText: "",
            poopsText: "Late to meeting.",
            weeklyGoal: "Write journal daily",
            monthlyGoal: "Learn a new recipe"
        )
    ]
}

// MARK: - Feed Page
struct FeedPageView: View {
    @ObservedObject var feed: FeedManager

    var body: some View {
        NavigationView {
            List {
                ForEach(feed.posts, id: \.id) { post in
                    NavigationLink(destination: FeedDetailView(checkIn: post)) {
                        FeedCardView(checkIn: post)
                    }
                }
            }
            .navigationTitle("Feed")
            .navigationBarBackButtonHidden(false)
        }
    }
}

// MARK: - Feed Card View
struct FeedCardView: View {
    @State private var isLiked = false
    @State private var isFollowed = false
    @State private var commentText = ""
    @State private var comments: [String] = []

    let checkIn: CheckInData

    private var likeCount: Int { isLiked ? 1 : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                (checkIn.profileImage ?? Image(systemName: "person.circle.fill"))
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                VStack(alignment: .leading) {
                    Text(checkIn.userName)
                        .font(.headline)
                    Text("\(checkIn.astrologySign) • Week \(checkIn.weekNumber) \(checkIn.weeklyEmoji)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { isFollowed.toggle() }) {
                    Text(isFollowed ? "Following" : "Follow")
                        .font(.caption)
                        .foregroundColor(isFollowed ? .green : .accentColor)
                }
            }

            if let image = checkIn.checkInImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let videoURL = checkIn.checkInVideoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let drawing = checkIn.drawingImage {
                Image(uiImage: drawing)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if !checkIn.emotionalInsight.isEmpty {
                Text(checkIn.emotionalInsight)
                    .font(.body)
                    .lineLimit(2)
            }

            if !checkIn.selectedEmotions.isEmpty {
                Text("Emotions: \(Array(checkIn.selectedEmotions).sorted().joined(separator: ", "))")
                    .font(.subheadline)
            }
            if !checkIn.weeklyGoal.isEmpty {
                Text("Weekly Goal: \(checkIn.weeklyGoal)")
                    .font(.subheadline)
            }

            HStack {
                Button(action: { isLiked.toggle() }) {
                    Label("\(likeCount) Like\(likeCount == 1 ? "" : "s")", systemImage: isLiked ? "heart.fill" : "heart")
                }
                Button(action: { comments.append("Nice post!") }) {
                    Label("\(comments.count) Comment\(comments.count == 1 ? "" : "s")", systemImage: "bubble.right")
                }
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.secondary)

            HStack {
                TextField("Add a comment...", text: $commentText)
                    .textFieldStyle(.roundedBorder)
                Button("Post") {
                    if !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        comments.append(commentText)
                        commentText = ""
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
}

// MARK: - Feed Detail View
struct FeedDetailView: View {
    let checkIn: CheckInData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    if let img = checkIn.checkInImage {
                        Image(uiImage: img)
                            .resizable()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text(checkIn.userName)
                            .font(.title2)
                            .bold()
                        Text("\(checkIn.astrologySign) • Week \(checkIn.weekNumber) \(checkIn.weeklyEmoji)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if checkIn.checkInImage != nil {
                    Image(uiImage: checkIn.checkInImage!)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if let videoURL = checkIn.checkInVideoURL {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if let drawing = checkIn.drawingImage {
                    Image(uiImage: drawing)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                if !checkIn.selectedEmotions.isEmpty {
                    Text("Emotions: \(Array(checkIn.selectedEmotions).sorted().joined(separator: ", "))")
                        .font(.body)
                }
                if !checkIn.emotionalInsight.isEmpty {
                    Text("Insight: \(checkIn.emotionalInsight)")
                        .font(.body)
                }
                if !checkIn.whoopsText.isEmpty {
                    Text("Whoops: \(checkIn.whoopsText)")
                        .font(.body)
                }
                if !checkIn.poopsText.isEmpty {
                    Text("Poops: \(checkIn.poopsText)")
                        .font(.body)
                }
                if !checkIn.weeklyGoal.isEmpty {
                    Text("Weekly Goal: \(checkIn.weeklyGoal)")
                        .font(.body)
                }
                if !checkIn.monthlyGoal.isEmpty {
                    Text("Monthly Goal: \(checkIn.monthlyGoal)")
                        .font(.body)
                }
            }
            .padding()
        }
        .navigationTitle("Wrapup Details")
        .navigationBarTitleDisplayMode(.inline)
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
 