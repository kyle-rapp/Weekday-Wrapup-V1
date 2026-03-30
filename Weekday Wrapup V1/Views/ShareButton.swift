import SwiftUI

struct ShareButton: View {
    let checkInData: CheckInData
    @State private var showingShareSheet = false
    
    var body: some View {
        Button {
            showingShareSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text("Share")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppTheme.colors.bark)
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
    }

    private var shareItems: [Any] {
        var items: [Any] = [checkInData.shareText]
        if let image = checkInData.checkInImage {
            items.append(image)
        }
        if let pdfData = PDFGenerator.generate(checkInData: checkInData),
           let pdfURL = PDFGenerator.writeToTemporaryFile(data: pdfData) {
            items.append(pdfURL)
        }
        return items
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 