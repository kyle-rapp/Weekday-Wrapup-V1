import SwiftUI

/// FILE: Navigation/TabRouter.swift
/// Shared tab selection + lightweight “posted” feedback for the main `TabView`.

enum MainAppTab: Hashable {
    case feed
    case share
    case learn
    case grow
}

@MainActor
final class TabRouter: ObservableObject {
    @Published var selectedTab: MainAppTab = .share
    @Published var postedToastVisible = false
    @Published var showPostCheckInReflection = false
    @Published var dailyRecommendations: DailyRecommendationsPresentation?
    @Published var focusDopamineMenuInGrow = false

    private var toastDismissTask: Task<Void, Never>?
    private var reflectionWorkItem: DispatchWorkItem?

    func presentDailyRecommendations(_ bundle: DailyRecommendationBundle) {
        dailyRecommendations = DailyRecommendationsPresentation(bundle: bundle)
    }

    func dismissDailyRecommendations() {
        dailyRecommendations = nil
    }

    func openDopamineMenuInGrow() {
        selectedTab = .grow
        focusDopamineMenuInGrow = true
    }

    func consumeDopamineMenuFocusRequest() {
        focusDopamineMenuInGrow = false
    }

    /// Call after a successful feed post: switches to Feed, shows toast, dismisses share sheet (caller dismisses sheet).
    func completePostToFeedFlow() {
        selectedTab = .feed
        postedToastVisible = true
        toastDismissTask?.cancel()
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            postedToastVisible = false
        }
    }

    /// Presents the reflection sheet ~8s after a successful feed post (Share flow survives via tab shell).
    func schedulePostCheckInReflection() {
        reflectionWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.showPostCheckInReflection = true
        }
        reflectionWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: item)
    }

    func dismissPostCheckInReflection() {
        reflectionWorkItem?.cancel()
        reflectionWorkItem = nil
        showPostCheckInReflection = false
    }
}
