//
//  ContentView.swift
//  Weekday Wrapup V1
//
//  Created by Shannon  Dupont on 12/14/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var emotionRouter: EmotionRouter

    // State variables
    @State private var showProfileCreation = true
    @State private var userName = ""
    @State private var profileImage: Image?
    @State private var astrologySign = ""
    @State private var weeklyEmoji = ""
    @State private var emotionalInsight = ""
    @State private var whoopsText = ""
    @State private var poopsText = ""
    @State private var weeklyGoal = ""
    @State private var monthlyGoal = ""
    @State private var capturedImage: UIImage?
    @State private var visibility: PostVisibility = .public

    private let emotionDefinitions: [String: String] = [
        "😊": "Feeling happy and content.",
        "😤": "Feeling frustrated or stressed.",
        "🥰": "Feeling loved or affectionate.",
        "💪": "Feeling strong or motivated.",
        "💭": "Feeling thoughtful or reflective.",
        "💫": "Feeling inspired or magical."
    ]

    // Get current week number
    private var weekNumber: Int {
        let calendar = Calendar.current
        return calendar.component(.weekOfYear, from: Date())
    }
    
    private var checkInData: CheckInData {
        CheckInData(
            userName: userName,
            astrologySign: astrologySign,
            weekNumber: weekNumber,
            weeklyEmoji: weeklyEmoji,
            checkInImage: capturedImage,
            selectedEmotions: emotionRouter.selectedEmotions,
            emotionalInsight: emotionalInsight,
            whoopsText: whoopsText,
            poopsText: poopsText,
            weeklyGoal: weeklyGoal,
            monthlyGoal: monthlyGoal,
            profileImage: profileImage,
            visibility: visibility
        )
    }

    var body: some View {
        VStack(spacing: 0) {
                // Fixed Header
                HStack(spacing: 12) {
                    ProfileImageView(image: profileImage)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.colors.sand.opacity(0.3), lineWidth: 1))
                        .shadow(color: AppTheme.colors.primary.opacity(0.1), radius: 2)
                        .onTapGesture {
                            showProfileCreation = true
                        }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: { showProfileCreation = true }) {
                            Text(userName.isEmpty ? "Welcome!" : userName)
                                .font(.headline)
                                .foregroundColor(AppTheme.colors.textPrimary)
                                .overlay(
                                    userName.isEmpty ?
                                    Rectangle()
                                        .fill(AppTheme.colors.textPrimary)
                                        .frame(height: 1)
                                        .offset(y: 2)
                                        .opacity(0.3) : nil,
                                    alignment: .bottom
                                )
                        }
                        if !astrologySign.isEmpty {
                            Text(astrologySign)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()

                    Menu {
                        Button("Sign out", role: .destructive) {
                            Task {
                                await auth.signOut()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(AppTheme.colors.textPrimary.opacity(0.88))
                    }

                    WeekNumberView(weekNumber: weekNumber, emoji: $weeklyEmoji)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.colors.background)
                        .shadow(color: AppTheme.colors.bark.opacity(0.05), radius: 8, y: 2)
                )
                .padding(.horizontal)
                
                // Scrollable Content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 32) {
                        // Camera section
                        SectionContainer {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Capture Your Moment", icon: "camera.fill", color: AppTheme.colors.ocean)
                                
                                MediaCaptureView(capturedImage: $capturedImage)
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                        
                        // Feeling wheel section
                        SectionContainer {
                            VStack(spacing: 20) {
                                SectionHeader(title: "Express Your Feelings", icon: "heart.fill", color: AppTheme.colors.moss)

                                FeelingWheelView(
                                    selectedEmotions: Binding(
                                        get: { emotionRouter.selectedEmotions },
                                        set: { emotionRouter.updateSelection($0) }
                                    )
                                )
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(maxWidth: 500)
                                    .frame(minHeight: 520)
                                    .padding(.vertical, 12)

                                if let key = emotionRouter.lastSelectedEmotion
                                    ?? emotionRouter.selectedEmotions.first, !key.isEmpty {
                                    let definition = emotionDefinitions[key]
                                        ?? LearnEmotionDefinitionLookup.definition(for: key)
                                    Text(definition)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                        .transition(.opacity)
                                        .animation(.easeInOut(duration: 0.2), value: emotionRouter.lastSelectedEmotion)
                                }

                                if !emotionRouter.selectedEmotions.isEmpty {
                                    EmotionSummaryView(emotions: emotionRouter.selectedEmotions)
                                        .id("emotionSummary")
                                        .transition(.opacity)
                                }
                            }
                            .onChange(of: emotionRouter.selectedEmotions) {
                                withAnimation {
                                    proxy.scrollTo("emotionSummary", anchor: .center)
                                }
                            }
                        }
                        
                        // Input sections
                        SectionContainer {
                            VStack(spacing: 24) {
                                SectionHeader(title: "Your Reflections", icon: "pencil.line", color: AppTheme.colors.bark)
                                
                                InsightInputView(text: $emotionalInsight)
                                
                                // Whoops and Poops row
                                HStack(spacing: 16) {
                                    WhoopsInputView(text: $whoopsText)
                                    PoopsInputView(text: $poopsText)
                                }
                                
                                // Goals column
                                VStack(spacing: 16) {
                                    WeeklyGoalInputView(text: $weeklyGoal)
                                    MonthlyGoalInputView(text: $monthlyGoal)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Who can see this wrapup?", systemImage: "lock.fill")
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.colors.textPrimary)
                                    Picker("Visibility", selection: $visibility) {
                                        ForEach(PostVisibility.allCases, id: \.self) { option in
                                            Text(option.rawValue).tag(option)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        }
                        }
                    }
                }
                .background(AppTheme.colors.secondaryBackground)

                // Footer
                FooterView(checkInData: checkInData)
        }
        .background(AppTheme.colors.secondaryBackground)
        .sheet(isPresented: $showProfileCreation) {
            ProfileCreationView(isPresented: $showProfileCreation,
                              userName: $userName,
                              profileImage: $profileImage,
                              astrologySign: $astrologySign)
        }
    }
}

// Helper Views
struct SectionContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.colors.background)
                    .shadow(color: AppTheme.colors.bark.opacity(0.05), radius: 8, y: 2)
            )
            .padding(.horizontal, 16)
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 18, weight: .semibold))
                .frame(minWidth: 24)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.colors.textPrimary)
        }
        .frame(height: 44)
    }
}

#if DEBUG
#Preview("Home (mock)") {
    ContentViewPreviewHost()
}

private struct ContentViewPreviewHost: View {
    @StateObject private var auth = AuthManager(previewLoggedIn: true, previewUser: PreviewSampleData.currentUser)
    @StateObject private var tabRouter = TabRouter()
    @StateObject private var feedViewModel = FeedViewModel()
    @StateObject private var emotionRouter = EmotionRouter()
    private let firestore = FirestoreManager.shared

    var body: some View {
        ContentView()
            .environmentObject(auth)
            .environmentObject(firestore)
            .environmentObject(tabRouter)
            .environmentObject(feedViewModel)
            .environmentObject(emotionRouter)
            .onAppear {
                firestore.applyPreviewPosts(PreviewSampleData.sampleFeedPosts)
            }
    }
}
#endif

