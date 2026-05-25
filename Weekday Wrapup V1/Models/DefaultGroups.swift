import Foundation

/// FILE: Models/DefaultGroups.swift
/// Seed data for the 100 default mental-health support groups.

struct DefaultGroups {
    static let all: [String] = [
        // Anxiety & Stress
        "General Anxiety",
        "Social Anxiety",
        "Panic Attacks",
        "Health Anxiety",
        "Overthinking",
        "Burnout",
        "Work Stress",
        "School Stress",
        "Decision Anxiety",
        "Chronic Stress",

        // Depression
        "Depression Support",
        "High-Functioning Depression",
        "Seasonal Depression",
        "Post-Breakup Healing",
        "Loneliness",
        "Loss of Motivation",
        "Emotional Numbness",
        "Grief Support",
        "Existential Thoughts",
        "Hopelessness",

        // Trauma
        "PTSD",
        "Childhood Trauma",
        "Emotional Abuse Recovery",
        "Narcissistic Abuse",
        "Relationship Trauma",
        "Grief & Loss",
        "Medical Trauma",
        "War Trauma",
        "Accident Recovery",
        "Healing Journey",

        // Neurodivergence
        "ADHD",
        "ADHD (Adults)",
        "Autism Spectrum",
        "Executive Dysfunction",
        "Sensory Sensitivity",
        "Focus & Productivity",
        "Routine Building",
        "Emotional Regulation",
        "Time Blindness",
        "Overstimulation",

        // Mood Disorders
        "Bipolar I",
        "Bipolar II",
        "Mood Swings",
        "Emotional Intensity",
        "Irritability",
        "Mania Support",
        "Stability Seeking",
        "Energy Crashes",
        "Sleep & Mood",
        "Tracking Patterns",

        // Relationships
        "Relationship Anxiety",
        "Attachment Styles",
        "Avoidant Attachment",
        "Anxious Attachment",
        "Breakups",
        "Divorce Support",
        "Communication Skills",
        "Conflict Resolution",
        "Trust Issues",
        "Boundaries",

        // Self & Growth
        "Self-Esteem",
        "Confidence Building",
        "Identity & Purpose",
        "People Pleasing",
        "Perfectionism",
        "Inner Critic",
        "Authenticity",
        "Life Direction",
        "Personal Growth",
        "Habits & Change",

        // Coping & Recovery
        "Healthy Coping",
        "Addiction Recovery",
        "Sobriety",
        "Urge Management",
        "Relapse Support",
        "Emotional Eating",
        "Dopamine Reset",
        "Digital Detox",
        "Anger Management",
        "Grounding Techniques",

        // Social & Life
        "Making Friends",
        "Isolation",
        "Life Transitions",
        "Moving Cities",
        "Career Uncertainty",
        "Financial Stress",
        "Family Issues",
        "Parenting Stress",
        "College Life",
        "Adulting",

        // Positive States
        "Gratitude",
        "Joy & Play",
        "Mindfulness",
        "Meditation",
        "Self-Care",
        "Nature & Outdoors",
        "Creativity",
        "Fitness & Mood",
        "Small Wins",
        "Daily Positivity",
        "OCD",
        "Trauma Recovery",
        "Bipolar Support",
        "Men's Support",
        "Women's Support",
    ]

    /// Category label for display grouping (derived from array position above).
    static let categories: [String] = [
        "Anxiety & Stress",
        "Depression",
        "Trauma",
        "Neurodivergence",
        "Mood Disorders",
        "Relationships",
        "Self & Growth",
        "Coping & Recovery",
        "Social & Life",
        "Positive States",
    ]

    static func groups(inCategory index: Int) -> [String] {
        guard index >= 0, index < categories.count else { return [] }
        let start = index * 10
        let end = min(start + 10, all.count)
        return Array(all[start..<end])
    }

    static func categoryForGroup(named name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("ocd") || lower.contains("adhd") || lower.contains("autism") || lower.contains("executive") || lower.contains("sensory") {
            return "Neurodivergence"
        }
        if lower.contains("bipolar") || lower.contains("mood") || lower.contains("mania") {
            return "Mood Disorders"
        }
        if lower.contains("trauma") || lower.contains("ptsd") {
            return "Trauma"
        }
        if lower.contains("men's support") || lower.contains("women's support") {
            return "Social & Life"
        }
        if lower.contains("grief") || lower.contains("loss") {
            return "Depression"
        }
        if lower.contains("burnout") || lower.contains("stress") || lower.contains("anxiety") || lower.contains("panic") {
            return "Anxiety & Stress"
        }
        if let idx = all.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            let catIndex = min(categories.count - 1, max(0, idx / 10))
            return categories[catIndex]
        }
        return "Self & Growth"
    }

    static func tagsForGroup(name: String, description: String?) -> [String] {
        let base = [name, description ?? "", categoryForGroup(named: name)].joined(separator: " ").lowercased()
        var tags: [String] = []
        if base.contains("ptsd") || base.contains("post traumatic stress") || base.contains("post-traumatic stress") {
            tags.append("ptsd")
            tags.append("post traumatic stress disorder")
            tags.append("post-traumatic stress disorder")
            tags.append("trauma")
        }
        if base.contains("anxiety") || base.contains("panic") || base.contains("overthink") { tags.append("anxiety") }
        if base.contains("adhd") || base.contains("executive") || base.contains("time blindness") { tags.append("adhd") }
        if base.contains("grief") || base.contains("loss") { tags.append("grief") }
        if base.contains("burnout") || base.contains("stress") {
            tags.append("burnout")
            tags.append("workplace stress")
            tags.append("exhaustion")
            tags.append("overwhelm")
        }
        if base.contains("depress") || base.contains("hopeless") || base.contains("numb") { tags.append("depression") }
        if base.contains("trauma") || base.contains("ptsd") { tags.append("trauma") }
        if base.contains("relationship") || base.contains("attachment") || base.contains("breakup") { tags.append("relationships") }
        if base.contains("self") || base.contains("confidence") || base.contains("identity") { tags.append("self-growth") }
        if base.contains("recovery") || base.contains("coping") || base.contains("sobriety") { tags.append("recovery") }
        if base.contains("mindful") || base.contains("meditation") || base.contains("gratitude") { tags.append("mindfulness") }
        tags.append(categoryForGroup(named: name).lowercased())
        var seen = Set<String>()
        return tags.filter { seen.insert($0).inserted }
    }

    static func searchKeywordsForGroup(name: String, description: String?) -> [String] {
        let base = [name, description ?? "", categoryForGroup(named: name)].joined(separator: " ").lowercased()
        var keywords = tagsForGroup(name: name, description: description)
        keywords.append(name.lowercased())

        if base.contains("ptsd") || base.contains("post traumatic stress") || base.contains("trauma") {
            keywords.append(contentsOf: [
                "ptsd",
                "post traumatic stress",
                "post traumatic stress disorder",
                "post-traumatic stress",
                "post-traumatic stress disorder",
                "trauma",
                "trauma recovery"
            ])
        }
        if base.contains("burnout") || base.contains("work stress") || base.contains("stress") {
            keywords.append(contentsOf: [
                "burnout",
                "burn out",
                "workplace stress",
                "work stress",
                "exhaustion",
                "emotional exhaustion",
                "overwhelm",
                "chronic stress"
            ])
        }
        if base.contains("ocd") {
            keywords.append(contentsOf: ["ocd", "obsessive compulsive disorder"])
        }
        var seen = Set<String>()
        return keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
