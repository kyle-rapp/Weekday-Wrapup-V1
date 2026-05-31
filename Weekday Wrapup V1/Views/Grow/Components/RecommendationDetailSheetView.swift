import SwiftUI

struct RecommendationDetailSheetView: View {
    let recommendation: Recommendation
    var selectedFeedback: Bool?
    var onFeedback: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var detail: RecommendationDetailContent {
        RecommendationDetailContent.make(for: recommendation)
    }

    private var externalResourceURL: URL? {
        if let raw = recommendation.resourceURL ?? RecommendationResourceEngine.url(matchingTitle: recommendation.title),
           let url = URL(string: raw),
           url.scheme?.hasPrefix("http") == true {
            return url
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recommendation.title)
                            .font(.title2.bold())
                        Text(detail.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    detailSection(title: "How to try it", rows: detail.steps)
                    detailSection(title: "Why it may help", rows: [detail.whyItHelps])

                    if let url = externalResourceURL {
                        Button {
                            openURL(url)
                        } label: {
                            Label("Open Resource", systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.colors.ocean)
                    }

                    HStack(spacing: 12) {
                        Button {
                            onFeedback(true)
                        } label: {
                            Label(selectedFeedback == true ? "Marked helpful" : "This helped", systemImage: "hand.thumbsup.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.colors.pine)

                        Button {
                            onFeedback(false)
                        } label: {
                            Label("Not for me", systemImage: "hand.thumbsdown")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .navigationTitle(recommendation.action)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    private func detailSection(title: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .top, spacing: 8) {
                        Text(rows.count > 1 ? "\(index + 1)." : "•")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.colors.ocean)
                        Text(row)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.colors.secondaryBackground)
        )
    }
}

private struct RecommendationDetailContent {
    let summary: String
    let steps: [String]
    let whyItHelps: String

    static func make(for recommendation: Recommendation) -> RecommendationDetailContent {
        let text = "\(recommendation.title) \(recommendation.reason) \(recommendation.action) \(recommendation.tags.joined(separator: " "))".lowercased()

        if text.contains("5-4-3-2-1") || text.contains("ground") {
            return RecommendationDetailContent(
                summary: "A simple grounding practice that brings attention back to the present moment.",
                steps: [
                    "Name 5 things you can see.",
                    "Name 4 things you can feel.",
                    "Name 3 things you can hear.",
                    "Name 2 things you can smell.",
                    "Name 1 thing you can taste."
                ],
                whyItHelps: "Grounding gives your mind concrete sensory information, which can soften spiraling thoughts and help your body feel safer now."
            )
        }

        if text.contains("breath") || text.contains("breathe") {
            return RecommendationDetailContent(
                summary: "A low-effort reset for moments when your body feels activated.",
                steps: [
                    "Sit or stand somewhere steady.",
                    "Inhale slowly through your nose for 4 counts.",
                    "Exhale gently for 6 counts.",
                    "Repeat 4 to 6 times without forcing it."
                ],
                whyItHelps: "Longer exhales can cue your nervous system toward calm without needing to solve everything at once."
            )
        }

        if text.contains("walk") || text.contains("movement") || text.contains("move") {
            return RecommendationDetailContent(
                summary: "A gentle way to move emotional energy through your body.",
                steps: [
                    "Choose a tiny route or a 5-minute timer.",
                    "Walk at a comfortable pace.",
                    "Notice one color, sound, or texture around you.",
                    "Stop before it feels like a chore."
                ],
                whyItHelps: "Movement can reduce stuck energy and create a small sense of momentum without demanding a full workout."
            )
        }

        if text.contains("journal") || text.contains("reflect") || text.contains("write") {
            return RecommendationDetailContent(
                summary: "A reflective prompt to help the feeling become clearer and less tangled.",
                steps: [
                    "Write one sentence: \"Right now I feel...\"",
                    "Write one sentence: \"What I may need is...\"",
                    "Write one tiny next step you could take.",
                    "Stop after a few minutes if that feels like enough."
                ],
                whyItHelps: "Naming feelings and needs can reduce emotional noise and make the next step feel more possible."
            )
        }

        if text.contains("message") || text.contains("friend") || text.contains("connection") || text.contains("reach out") {
            return RecommendationDetailContent(
                summary: "A small connection step that avoids pressure or overexplaining.",
                steps: [
                    "Pick one safe person.",
                    "Send a short note like: \"Thinking of you. Could use a little connection today.\"",
                    "Let the message be simple.",
                    "Choose one grounding action while you wait."
                ],
                whyItHelps: "Gentle connection can interrupt isolation while keeping the ask clear and manageable."
            )
        }

        return RecommendationDetailContent(
            summary: recommendation.reason,
            steps: [
                "Start with the smallest version of this action.",
                "Set a short timer if that makes it easier.",
                "Notice how your body feels before and after.",
                "Stop or adjust if it starts to feel pressuring."
            ],
            whyItHelps: "Small supportive actions can create stability and self-trust, especially when they match your current energy."
        )
    }
}
