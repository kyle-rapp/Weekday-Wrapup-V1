import SwiftUI

struct CheckInData {
    let userName: String
    let astrologySign: String
    let weekNumber: Int
    let weeklyEmoji: String
    let checkInImage: UIImage?
    let selectedEmotions: Set<String>
    let emotionalInsight: String
    let whoopsText: String
    let poopsText: String
    let weeklyGoal: String
    let monthlyGoal: String
    
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