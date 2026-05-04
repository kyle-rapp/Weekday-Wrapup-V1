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
    @StateObject private var authManager: AuthManager
    @StateObject private var emotionRouter = EmotionRouter()
    private let isUITestMode: Bool

    init() {
        let args = ProcessInfo.processInfo.arguments
        isUITestMode = args.contains("--uitest-mode")
        #if DEBUG
        if isUITestMode {
            _authManager = StateObject(
                wrappedValue: AuthManager(
                    previewLoggedIn: true,
                    previewUser: AppUser(
                        id: "uitest-user",
                        name: "UI Test User",
                        email: "uitest@weekday.app"
                    )
                )
            )
        } else {
            _authManager = StateObject(wrappedValue: AuthManager())
        }
        #else
        _authManager = StateObject(wrappedValue: AuthManager())
        #endif

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            FirebaseApp.configure()
            if FirebaseApp.app() == nil {
                AppLogger.error("FirebaseApp failed to configure. Verify GoogleService-Info.plist is included in target.")
            } else {
                AppLogger.log("FirebaseApp configured successfully.")
            }
            if !isUITestMode {
                NotificationManager.shared.requestPermission()
                NotificationManager.shared.scheduleCheckInReminder()
            }
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
    private var shouldSeedDemoData: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--seed-firestore-if-empty") && !args.contains("--uitest-mode")
    }

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
                if shouldSeedDemoData {
                    Task { await firestore.seedFirestoreIfEmpty() }
                }
                #if DEBUG
                Task { await firestore.seedTestData() }
                #endif
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
                if shouldSeedDemoData {
                    Task { await firestore.seedFirestoreIfEmpty() }
                }
                #if DEBUG
                Task { await firestore.seedTestData() }
                #endif
                if let uid = auth.currentUser?.id {
                    firestore.startFollowingListener(userId: uid)
                    firestore.startGroupsListener(userId: uid)
                }
            }
        }
    }
}
