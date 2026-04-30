//
//  Weekday_Wrapup_V1App.swift
//  Weekday Wrapup V1
//
//  Created by Shannon  Dupont on 12/14/24.
//

import SwiftUI
import FirebaseCore

/// FILE: Weekday_Wrapup_V1App.swift
/// Configures Firebase and switches between auth and the main app.

@main
struct Weekday_Wrapup_V1App: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var emotionRouter = EmotionRouter()

    init() {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            FirebaseApp.configure()
            NotificationManager.shared.requestPermission()
            NotificationManager.shared.scheduleCheckInReminder()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(FirestoreManager.shared)
                .environmentObject(emotionRouter)
        }
    }
}

/// FILE: RootView (in Weekday_Wrapup_V1App.swift)
private struct RootView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var firestore: FirestoreManager

    var body: some View {
        Group {
            if auth.isLoggedIn {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.isLoggedIn)
        .onChange(of: auth.isLoggedIn) { _, loggedIn in
            if loggedIn {
                firestore.startPostsListener()
            } else {
                firestore.teardownForLogout()
            }
        }
        .onChange(of: auth.currentUser?.id) { _, uid in
            guard auth.isLoggedIn, let uid else { return }
            firestore.startFollowingListener(userId: uid)
            firestore.startGroupsListener(userId: uid)
        }
        .onAppear {
            if auth.isLoggedIn {
                firestore.startPostsListener()
                if let uid = auth.currentUser?.id {
                    firestore.startFollowingListener(userId: uid)
                    firestore.startGroupsListener(userId: uid)
                }
            }
        }
    }
}
