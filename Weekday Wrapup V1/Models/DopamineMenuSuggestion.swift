import Foundation

enum DopamineCategory: String, CaseIterable, Identifiable {
    case appetizer = "Appetizer"
    case entree = "Entrée"
    case side = "Side"
    case dessert = "Dessert"
    case special = "Special"

    var id: String { rawValue }
}

struct DopamineMenuSuggestion {
    let title: String
    let category: DopamineCategory
    let description: String?
}

struct DopamineSuggestionMetadata {
    let overstimulationRisk: Bool
    let warning: String?
    let sideAlternative: String?
}

enum DopamineSuggestionLibrary {
    static let all: [DopamineMenuSuggestion] = [
        // Appetizers (10)
        DopamineMenuSuggestion(title: "1 minute jumping jacks", category: .appetizer, description: "Fast body reset when you feel stuck."),
        DopamineMenuSuggestion(title: "Drink coffee or tea", category: .appetizer, description: "A warm ritual to restart your focus."),
        DopamineMenuSuggestion(title: "Listen to your favorite song", category: .appetizer, description: "Quick mood lift without a huge time commitment."),
        DopamineMenuSuggestion(title: "Eat a small snack", category: .appetizer, description: "Fuel your brain before your next step."),
        DopamineMenuSuggestion(title: "Stretch for 2 minutes", category: .appetizer, description: "Loosen tension and reset posture."),
        DopamineMenuSuggestion(title: "Take a warm shower", category: .appetizer, description: "Comfort + sensory reset."),
        DopamineMenuSuggestion(title: "Step outside for fresh air", category: .appetizer, description: "Break the loop with a quick environment change."),
        DopamineMenuSuggestion(title: "Hug someone or pet an animal", category: .appetizer, description: "Gentle connection signal for your nervous system."),
        DopamineMenuSuggestion(title: "Quick breathing exercise", category: .appetizer, description: "Try one minute of slow exhale."),
        DopamineMenuSuggestion(title: "Look out the window for 60 seconds", category: .appetizer, description: "Micro-pause to reduce mental noise."),

        // Entrées (10)
        DopamineMenuSuggestion(title: "Walk or jog", category: .entree, description: "Sustained movement to release stress energy."),
        DopamineMenuSuggestion(title: "Play an instrument", category: .entree, description: "Channel focus into sound and rhythm."),
        DopamineMenuSuggestion(title: "Journaling session", category: .entree, description: "Process thoughts on paper without pressure."),
        DopamineMenuSuggestion(title: "Cooking or baking", category: .entree, description: "Hands-on task with a clear finish line."),
        DopamineMenuSuggestion(title: "Exercise workout", category: .entree, description: "Stronger physical reset when energy allows."),
        DopamineMenuSuggestion(title: "Creative hobby (drawing or painting)", category: .entree, description: "Express emotion nonverbally."),
        DopamineMenuSuggestion(title: "Puzzle (jigsaw or sudoku)", category: .entree, description: "Structured challenge for mental focus."),
        DopamineMenuSuggestion(title: "Call or meet a friend", category: .entree, description: "Longer social recharge."),
        DopamineMenuSuggestion(title: "Clean or organize your space", category: .entree, description: "External order can lower internal chaos."),
        DopamineMenuSuggestion(title: "Learn something new (video or course)", category: .entree, description: "Progress-oriented boost."),

        // Sides (10)
        DopamineMenuSuggestion(title: "Playlist for focus", category: .side, description: "Pair with tasks that feel boring."),
        DopamineMenuSuggestion(title: "Podcast while doing chores", category: .side, description: "Stack enjoyment with obligations."),
        DopamineMenuSuggestion(title: "Audiobook for low-energy tasks", category: .side, description: "Story-driven motivation."),
        DopamineMenuSuggestion(title: "ASMR video in the background", category: .side, description: "Soothing sound support."),
        DopamineMenuSuggestion(title: "Use a fidget tool", category: .side, description: "Keep hands busy while your mind works."),
        DopamineMenuSuggestion(title: "Timer-based gamification", category: .side, description: "Turn work into short rounds."),
        DopamineMenuSuggestion(title: "Body doubling session", category: .side, description: "Accountability through shared focus."),
        DopamineMenuSuggestion(title: "Instrumental music", category: .side, description: "Reduce distraction from lyrics."),
        DopamineMenuSuggestion(title: "White noise", category: .side, description: "Mask interruptions and keep momentum."),
        DopamineMenuSuggestion(title: "Task race timer challenge", category: .side, description: "Beat the clock for one sprint."),

        // Desserts (10)
        DopamineMenuSuggestion(title: "Social media scrolling", category: .dessert, description: "Use intentionally with a time boundary."),
        DopamineMenuSuggestion(title: "Texting friends", category: .dessert, description: "Quick social hit with low effort."),
        DopamineMenuSuggestion(title: "Watching TV", category: .dessert, description: "Comfort downtime when you need a pause."),
        DopamineMenuSuggestion(title: "Video games", category: .dessert, description: "Immersive break if used intentionally."),
        DopamineMenuSuggestion(title: "YouTube browsing", category: .dessert, description: "Short entertainment break."),
        DopamineMenuSuggestion(title: "Short-form video apps", category: .dessert, description: "Can be stimulating; set a cap first."),
        DopamineMenuSuggestion(title: "Browsing memes", category: .dessert, description: "Humor reset when emotions feel heavy."),
        DopamineMenuSuggestion(title: "Shopping apps", category: .dessert, description: "Light browsing with awareness."),
        DopamineMenuSuggestion(title: "News scrolling", category: .dessert, description: "Stay informed without spiraling."),
        DopamineMenuSuggestion(title: "Random internet browsing", category: .dessert, description: "Use with a clear time limit."),

        // Specials (10)
        DopamineMenuSuggestion(title: "Concert", category: .special, description: "Planned high-energy joy event."),
        DopamineMenuSuggestion(title: "Vacation", category: .special, description: "Restorative break with intentional planning."),
        DopamineMenuSuggestion(title: "Massage", category: .special, description: "Physical recovery and deep relaxation."),
        DopamineMenuSuggestion(title: "Nail salon visit", category: .special, description: "Self-care ritual and confidence boost."),
        DopamineMenuSuggestion(title: "Dinner out", category: .special, description: "Meaningful social time."),
        DopamineMenuSuggestion(title: "Comedy show", category: .special, description: "Laughter-focused mood reset."),
        DopamineMenuSuggestion(title: "Museum visit", category: .special, description: "Calm exploratory inspiration."),
        DopamineMenuSuggestion(title: "Weekend trip", category: .special, description: "Environment change to break routine."),
        DopamineMenuSuggestion(title: "Spa day", category: .special, description: "Deliberate nervous-system recovery."),
        DopamineMenuSuggestion(title: "Planned social event", category: .special, description: "Connection with structure and intention.")
    ]

    static func suggestions(for category: DopamineCategory) -> [DopamineMenuSuggestion] {
        all.filter { $0.category == category }
    }

    static func metadata(for suggestion: DopamineMenuSuggestion) -> DopamineSuggestionMetadata {
        let lowered = suggestion.title.lowercased()
        let socialRiskKeywords = [
            "social media", "scroll", "youtube", "short-form", "tiktok", "instagram",
            "facebook", "x ", "twitter", "news", "random internet", "shopping apps", "memes"
        ]
        let isRisky = socialRiskKeywords.contains { lowered.contains($0) }
        return DopamineSuggestionMetadata(
            overstimulationRisk: isRisky,
            warning: isRisky ? "This activity may lead to overstimulation." : nil,
            sideAlternative: isRisky ? "Try a Side alternative: playlist for focus or a timer-based challenge." : nil
        )
    }
}
