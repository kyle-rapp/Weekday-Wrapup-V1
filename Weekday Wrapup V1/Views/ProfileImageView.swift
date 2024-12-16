import SwiftUI

struct ProfileImageView: View {
    let image: Image?
    
    var body: some View {
        if let image = image {
            image
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .foregroundColor(.gray)
        }
    }
} 