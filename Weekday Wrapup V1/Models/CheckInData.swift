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
    let emotionalInsight: String
    let whoopsText: String
    let poopsText: String
    let weeklyGoal: String
    let monthlyGoal: String
    let profileImage: Image?

    init(userName: String, astrologySign: String, weekNumber: Int, weeklyEmoji: String,
         checkInImage: UIImage?, selectedEmotions: Set<String>, emotionalInsight: String,
         whoopsText: String, poopsText: String, weeklyGoal: String, monthlyGoal: String,
         profileImage: Image? = nil, checkInVideoURL: URL? = nil, drawingImage: UIImage? = nil, id: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.userName = userName
        self.astrologySign = astrologySign
        self.weekNumber = weekNumber
        self.weeklyEmoji = weeklyEmoji
        self.checkInImage = checkInImage
        self.checkInVideoURL = checkInVideoURL
        self.drawingImage = drawingImage
        self.selectedEmotions = selectedEmotions
        self.emotionalInsight = emotionalInsight
        self.whoopsText = whoopsText
        self.poopsText = poopsText
        self.weeklyGoal = weeklyGoal
        self.monthlyGoal = monthlyGoal
        self.profileImage = profileImage
    }
    
    var shareText: String {
        """
        Weekly Check-in (Week \(weekNumber)) \(weeklyEmoji)
        
        From: \(userName) \(astrologySign)
        
        Feeling: \(selectedEmotions.joined(separator: ", "))
        
        Insight: \(emotionalInsight)
        
        Whoops: \(whoopsText)
        Poops: \(poopsText)
        
        Weekly Goal: \(weeklyGoal)
        Monthly Goal: \(monthlyGoal)
        """
    }
} 