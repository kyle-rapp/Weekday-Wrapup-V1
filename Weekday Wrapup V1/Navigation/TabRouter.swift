import SwiftUI

/// FILE: Navigation/TabRouter.swift
/// Shared tab selection + lightweight “posted” feedback for the main `TabView`.

enum MainAppTab: Hashable {
    case feed
    case share
    case learn
}

@MainActor
final class TabRouter: ObservableObject {
    @Published var selectedTab: MainAppTab = .share
    @Published var postedToastVisible = false

    private var toastDismissTask: Task<Void, Never>?

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
}
