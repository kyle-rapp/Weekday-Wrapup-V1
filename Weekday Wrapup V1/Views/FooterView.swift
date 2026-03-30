import SwiftUI

// MARK: - Footer Update for Share
struct FooterView: View {
    let checkInData: CheckInData
    @State private var isShowingShareOptions = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { isShowingShareOptions = true }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .sheet(isPresented: $isShowingShareOptions) {
                ShareOptionsView(isShowing: $isShowingShareOptions, checkInData: checkInData)
            }

            NavigationLink(destination: FeedView()) {
                Label("Feed", systemImage: "person.3.fill")
            }
        }
        .padding()
    }
}

struct LikesView: View {
    @Binding var isShowing: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Likes")
                    .font(.headline)
                Spacer()
                Button("Done") { isShowing = false }
            }
            .padding()
            List {
                Text("Likes will appear here")
            }
        }
    }
}
