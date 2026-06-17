import SwiftUI

struct ProfileImageView: View {
    let image: Image?
    var imageURL: URL? = nil
    
    var body: some View {
        if let image = image {
            image
                .resizable()
                .scaledToFill()
        } else if let imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    ProgressView()
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
            Image(systemName: "person.circle.fill")
                .resizable()
                .foregroundColor(.gray)
    }
} 