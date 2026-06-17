import SwiftUI

struct CheckInData: Identifiable {
    let id: String
    let userName: String
    let astrologySign: String
    let weekNumber: Int
    let weeklyEmoji: String
    let checkInImage: UIImage?
    let checkInVideoURL: URL?
    let drawingImage: UIImage?
    let selectedEmotions: Set<String>
    /// Order preserved from the wheel / Firestore `selectedEmotions` array (first = primary for calendar tint).
    let selectedEmotionsOrdered: [String]
    let emotionalInsight: String
    /// Gratitude note captured during check-in.
    let gratitudeText: String
    let whoopsText: String
    let poopsText: String
    /// Anticipation / hope prompt replacing weekly + monthly goals.
    let lookForwardTo: String
    /// Legacy field; kept for older posts and Firestore compatibility.
    let weeklyGoal: String
    /// Legacy field; kept for older posts and Firestore compatibility.
    let monthlyGoal: String
    let profileImage: Image?
    let visibility: PostVisibility
    /// When this check-in was captured or posted (used for calendar and trends).
    let date: Date
    /// Optional 1–10 self-rated intensity for insights and the emotion calendar.
    let intensity: Int?
    /// Optional note: what helped last time (shown on repeat emotions).
    let whatHelped: String?
    /// True when a check-in was added directly from the calendar (not full wrapup flow).
    let manualEntry: Bool
    /// Preset tags: what helped this check-in (saved on post).
    let helpfulTags: [String]?
    /// When posting with group visibility, target group ids.
    let sharedGroupIds: [String]?
    /// Optional post title shown in feed cards.
    var title: String = ""
    /// Optional remote image URL shown in feed cards.
    let imageURL: String?
    /// Only post author sees reaction counts when true.
    var hideReactions: Bool = false
    /// Comment section hidden when true.
    var hideComments: Bool = false

    init(userName: String, astrologySign: String, weekNumber: Int, weeklyEmoji: String,
         checkInImage: UIImage?, selectedEmotions: Set<String>, emotionalInsight: String,
         gratitudeText: String = "", whoopsText: String, poopsText: String,
         lookForwardTo: String = "", weeklyGoal: String = "", monthlyGoal: String = "",
         profileImage: Image? = nil, checkInVideoURL: URL? = nil, drawingImage: UIImage? = nil,
         visibility: PostVisibility = .public, date: Date = Date(), intensity: Int? = nil,
         whatHelped: String? = nil, manualEntry: Bool = false, helpfulTags: [String]? = nil, sharedGroupIds: [String]? = nil,
         title: String = "", imageURL: String? = nil,
         selectedEmotionsOrdered: [String]? = nil,
         id: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.userName = userName
        self.astrologySign = astrologySign
        self.weekNumber = weekNumber
        self.weeklyEmoji = weeklyEmoji
        self.checkInImage = checkInImage
        self.checkInVideoURL = checkInVideoURL
        self.drawingImage = drawingImage
        self.selectedEmotions = selectedEmotions
        if let o = selectedEmotionsOrdered, !o.isEmpty {
            let filtered = o.filter { selectedEmotions.contains($0) }
            if !filtered.isEmpty {
                self.selectedEmotionsOrdered = filtered
            } else {
                self.selectedEmotionsOrdered = Array(selectedEmotions).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            }
        } else if selectedEmotions.isEmpty {
            self.selectedEmotionsOrdered = []
        } else {
            self.selectedEmotionsOrdered = Array(selectedEmotions).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        self.emotionalInsight = emotionalInsight
        self.gratitudeText = gratitudeText
        self.whoopsText = whoopsText
        self.poopsText = poopsText
        let resolvedLookForward = lookForwardTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? weeklyGoal.trimmingCharacters(in: .whitespacesAndNewlines)
            : lookForwardTo
        self.lookForwardTo = resolvedLookForward
        self.weeklyGoal = resolvedLookForward.isEmpty ? weeklyGoal : resolvedLookForward
        self.monthlyGoal = monthlyGoal
        self.profileImage = profileImage
        self.visibility = visibility
        self.date = date
        self.intensity = intensity
        self.whatHelped = whatHelped
        self.manualEntry = manualEntry
        self.helpfulTags = helpfulTags
        self.sharedGroupIds = sharedGroupIds
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.imageURL = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var shareText: String {
        let feelingLine = selectedEmotionsOrdered.isEmpty
            ? selectedEmotions.sorted().joined(separator: ", ")
            : selectedEmotionsOrdered.joined(separator: ", ")
        return """
        Weekly Check-in (Week \(weekNumber)) \(weeklyEmoji)

        From: \(userName) \(astrologySign)

        Feeling: \(feelingLine)

        Insight: \(emotionalInsight)

        Grateful for: \(gratitudeText)

        Whoops: \(whoopsText)
        Poops: \(poopsText)

        Looking forward to: \(lookForwardTo)

        Visibility: \(visibility.rawValue)
        """
    }

    /// Builds a lightweight row model from a posted wrapup (images omitted).
    static func fromPostedWrapup(_ post: FeedPost, astrologySign: String = "") -> CheckInData {
        CheckInData(
            userName: post.user.name,
            astrologySign: astrologySign,
            weekNumber: post.wrapupWeekNumber,
            weeklyEmoji: post.emoji,
            checkInImage: nil,
            selectedEmotions: Set(post.selectedEmotions),
            emotionalInsight: post.insight,
            gratitudeText: post.gratitudeText,
            whoopsText: post.whoop,
            poopsText: "",
            lookForwardTo: post.lookForwardTo.isEmpty ? post.goal : post.lookForwardTo,
            weeklyGoal: post.goal,
            monthlyGoal: "",
            profileImage: nil,
            checkInVideoURL: nil,
            visibility: post.visibility,
            date: post.createdAt ?? Date(),
            intensity: post.intensity,
            whatHelped: post.whatHelped,
            manualEntry: post.manualEntry,
            helpfulTags: post.helpfulTags.isEmpty ? nil : post.helpfulTags,
            sharedGroupIds: post.sharedGroupIds.isEmpty ? nil : post.sharedGroupIds,
            title: post.title ?? "",
            imageURL: post.imageURL,
            selectedEmotionsOrdered: post.selectedEmotions,
            id: post.id
        )
    }
}

extension CheckInData {
    /// Array view of emotion labels for analytics / recommendations (`Set` remains the stored form for Firestore and UI uniqueness).
    var selectedEmotionsArray: [String] {
        Array(selectedEmotions).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// First emotion for calendar / summaries (ordered when available).
    var firstSelectedEmotionLabel: String {
        if let first = selectedEmotionsOrdered.first, !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return first
        }
        return selectedEmotionsArray.first ?? ""
    }
}
