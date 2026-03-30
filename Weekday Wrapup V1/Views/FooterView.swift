import SwiftUI

// MARK: - Footer Update for Share
struct FooterView: View {
    let checkInData: CheckInData
    @State private var isShowingShareOptions = false
    @ObservedObject var feed = FeedManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { isShowingShareOptions = true }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .sheet(isPresented: $isShowingShareOptions) {
                ShareOptionsView(isShowing: $isShowingShareOptions, checkInData: checkInData)
            }

            NavigationLink(destination: FeedPageView(feed: feed)) {
                Label("Feed", systemImage: "list.bullet")
            }
        }
        .padding()
    }
}

struct LikesView: View {
    @Binding var isShowing: Bool

    var body: some View {
        NavigationView {
            List {
                Text("Likes will appear here")
            }
            .navigationTitle("Likes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isShowing = false }
                }
            }
        }
    }
}
