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
    let whoopsText: String
    let poopsText: String
    let weeklyGoal: String
    let monthlyGoal: String
    let profileImage: Image?
    let visibility: PostVisibility
    /// When this check-in was captured or posted (used for calendar and trends).
    let date: Date
    /// Optional 1–10 self-rated intensity for insights and the emotion calendar.
    let intensity: Int?
    /// Optional note: what helped last time (shown on repeat emotions).
    let whatHelped: String?
    /// Preset tags: what helped this check-in (saved on post).
    let helpfulTags: [String]?
    /// When posting with group visibility, target group ids.
    let sharedGroupIds: [String]?

    init(userName: String, astrologySign: String, weekNumber: Int, weeklyEmoji: String,
         checkInImage: UIImage?, selectedEmotions: Set<String>, emotionalInsight: String,
         whoopsText: String, poopsText: String, weeklyGoal: String, monthlyGoal: String,
         profileImage: Image? = nil, checkInVideoURL: URL? = nil, drawingImage: UIImage? = nil,
         visibility: PostVisibility = .public, date: Date = Date(), intensity: Int? = nil,
         whatHelped: String? = nil, helpfulTags: [String]? = nil, sharedGroupIds: [String]? = nil,
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
        self.whoopsText = whoopsText
        self.poopsText = poopsText
        self.weeklyGoal = weeklyGoal
        self.monthlyGoal = monthlyGoal
        self.profileImage = profileImage
        self.visibility = visibility
        self.date = date
        self.intensity = intensity
        self.whatHelped = whatHelped
        self.helpfulTags = helpfulTags
        self.sharedGroupIds = sharedGroupIds
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

        Whoops: \(whoopsText)
        Poops: \(poopsText)

        Weekly Goal: \(weeklyGoal)
        Monthly Goal: \(monthlyGoal)

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
            whoopsText: post.whoop,
            poopsText: "",
            weeklyGoal: post.goal,
            monthlyGoal: "",
            profileImage: nil,
            visibility: post.visibility,
            date: post.createdAt ?? Date(),
            intensity: post.intensity,
            whatHelped: post.whatHelped,
            helpfulTags: post.helpfulTags.isEmpty ? nil : post.helpfulTags,
            sharedGroupIds: post.sharedGroupIds.isEmpty ? nil : post.sharedGroupIds,
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
