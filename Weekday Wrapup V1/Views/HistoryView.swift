import SwiftUI

/// FILE: Views/HistoryView.swift
/// Past wrapups for the signed-in user (from feed-backed posts).

struct HistoryView: View {
    let entries: [CheckInData]

    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var feedViewModel: FeedViewModel

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No past wrapups yet",
                    systemImage: "calendar",
                    description: Text("When you post from Share, your weeks show up here.")
                )
            } else {
                List(entries) { entry in
                    Group {
                        if let post = firestore.feedPost(byId: entry.id) {
                            NavigationLink {
                                PostDetailView(post: post)
                                    .environmentObject(firestore)
                                    .environmentObject(auth)
                                    .environmentObject(feedViewModel)
                            } label: {
                                PastWrapupRow(entry: entry)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            PastWrapupRow(entry: entry)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Past weeks")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.colors.secondaryBackground.ignoresSafeArea())
    }
}

// MARK: - Row

private struct PastWrapupRow: View {
    let entry: CheckInData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Week \(entry.weekNumber)")
                .font(.headline)
                .foregroundStyle(AppTheme.colors.textPrimary)
            Text(entry.selectedEmotions.sorted().joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(AppTheme.colors.textSecondary)
            if !entry.emotionalInsight.isEmpty {
                Text(entry.emotionalInsight)
                    .font(.caption)
                    .foregroundStyle(AppTheme.colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        HistoryView(entries: [
            CheckInData(
                userName: "Alex",
                astrologySign: "♈︎",
                weekNumber: 12,
                weeklyEmoji: "🌿",
                checkInImage: nil,
                selectedEmotions: Set(["Peaceful", "Hopeful"]),
                emotionalInsight: "Steady week.",
                whoopsText: "",
                poopsText: "",
                weeklyGoal: "Walk daily",
                monthlyGoal: "",
                selectedEmotionsOrdered: ["Peaceful", "Hopeful"]
            )
        ])
        .environmentObject(FirestoreManager.shared)
        .environmentObject(AuthManager(previewLoggedIn: true, previewUser: PreviewSampleData.currentUser))
        .environmentObject(FeedViewModel())
    }
}
#endif
