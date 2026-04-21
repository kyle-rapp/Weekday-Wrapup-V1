import SwiftUI

/// FILE: Views/MainTabView.swift
/// Root tab shell: Feed (single `NavigationStack`), Share, Learn. Owns `FeedViewModel` for feed navigation.

struct MainTabView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var firestore: FirestoreManager
    @StateObject private var feedViewModel = FeedViewModel()
    @StateObject private var tabRouter = TabRouter()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tabRouter.selectedTab) {
                NavigationStack(path: $feedViewModel.path) {
                    FeedView()
                        .navigationDestination(for: FeedPost.self) { post in
                            PostDetailView(post: post)
                        }
                }
                .tabItem {
                    Label("Feed", systemImage: "person.3.fill")
                }
                .tag(MainAppTab.feed)

                NavigationStack {
                    ContentView()
                }
                .tabItem {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tag(MainAppTab.share)

                NavigationStack {
                    LearnView()
                }
                .tabItem {
                    Label("Learn", systemImage: "book.fill")
                }
                .tag(MainAppTab.learn)
            }
            .environmentObject(tabRouter)
            .environmentObject(feedViewModel)

            if tabRouter.postedToastVisible {
                Text("Posted to Feed ✅")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.35, green: 0.55, blue: 0.42))
                            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                    )
                    .padding(.bottom, 28)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: tabRouter.postedToastVisible)
    }
}
