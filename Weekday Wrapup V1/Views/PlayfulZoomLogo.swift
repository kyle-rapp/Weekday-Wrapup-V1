import SwiftUI

struct PlayfulZoomLogo: View {
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(.white)
                .frame(width: 28, height: 28)
            
            // Camera body
            RoundedRectangle(cornerRadius: 6)
                .fill(AppTheme.colors.moss)
                .frame(width: 20, height: 16)
            
            // Camera lens
            Circle()
                .fill(.white)
                .frame(width: 10, height: 10)
                .offset(x: 0, y: 0)
            
            // Flash light
            Circle()
                .fill(.white)
                .frame(width: 4, height: 4)
                .offset(x: 6, y: -4)
        }
    }
} 