import SwiftUI

struct FooterView: View {
    @State private var showingLikesSheet = false
    @State private var isLiked = false
    let checkInData: CheckInData
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 32) {
                // Like Button
                Button {
                    isLiked.toggle()
                    if isLiked {
                        showingLikesSheet = true
                    }
                } label: {
                    VStack {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .resizable()
                            .frame(width: 24, height: 22)
                            .foregroundColor(isLiked ? .red : .black)
                        
                        Text("Like")
                            .font(.caption)
                            .foregroundColor(.black)
                    }
                    .padding(.vertical, 8)
                }
                
                // Share Button
                Button {
                    // Share action
                } label: {
                    VStack {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.purple)
                        
                        Text("Share")
                            .font(.caption)
                            .foregroundColor(.black)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Divider()
                .foregroundColor(.gray.opacity(0.3))
        }
        .background(Color.white)
        .sheet(isPresented: $showingLikesSheet) {
            LikesView(isShowing: $showingLikesSheet)
        }
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