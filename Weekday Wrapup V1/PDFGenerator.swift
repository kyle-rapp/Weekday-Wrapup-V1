import UIKit

// MARK: - PDF Generator

enum PDFGenerator {

    /// Generates a weekly wrapup PDF including logo, emoji, image, emotions, insight, Whoops/Poops, and goals.
    static func generate(checkInData: CheckInData) -> Data? {
        let pageSize = CGSize(width: 612, height: 792) // US Letter
        let margin: CGFloat = 20
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        let data = renderer.pdfData { context in
            context.beginPage()
            var currentY: CGFloat = 40

            // 1. Logo at top center
            let logoRect = CGRect(x: (pageSize.width - 100) / 2, y: currentY, width: 100, height: 40)
            drawLogo(in: logoRect)
            currentY += 50

            // 2. Week number and emoji
            let headerText = "Week \(checkInData.weekNumber)"
            if !checkInData.weeklyEmoji.isEmpty {
                let emojiStr = "\(headerText) \(checkInData.weeklyEmoji)"
                let emojiAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 24),
                    .foregroundColor: UIColor.label
                ]
                let emojiRect = CGRect(x: margin, y: currentY, width: pageSize.width - 2 * margin, height: 36)
                (emojiStr as NSString).draw(in: emojiRect, withAttributes: emojiAttributes)
            } else {
                let attr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 20),
                    .foregroundColor: UIColor.label
                ]
                (headerText as NSString).draw(in: CGRect(x: margin, y: currentY, width: pageSize.width - 2 * margin, height: 28), withAttributes: attr)
            }
            currentY += 44

            // 3. Captured image
            if let image = checkInData.checkInImage {
                let imgWidth = pageSize.width - 2 * margin
                let maxHeight: CGFloat = 220
                let aspect = image.size.height / image.size.width
                let imgHeight = min(imgWidth * aspect, maxHeight)
                let imgRect = CGRect(x: margin, y: currentY, width: imgWidth, height: imgHeight)
                image.draw(in: imgRect)
                currentY += imgHeight + 16
            }

            // 4. Selected emotions
            let emotionsText = checkInData.selectedEmotions.isEmpty ? "—" : checkInData.selectedEmotions.sorted().joined(separator: ", ")
            drawBox(
                in: CGRect(x: margin, y: currentY, width: pageSize.width - 2 * margin, height: 72),
                title: "Emotions",
                content: emotionsText,
                style: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.label]
            )
            currentY += 88

            // 5. Emotional insight
            drawBox(
                in: CGRect(x: margin, y: currentY, width: pageSize.width - 2 * margin, height: 92),
                title: "Emotional Insight",
                content: checkInData.emotionalInsight.isEmpty ? "—" : checkInData.emotionalInsight,
                style: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.label]
            )
            currentY += 108

            // 5b. Gratitude
            drawBox(
                in: CGRect(x: margin, y: currentY, width: pageSize.width - 2 * margin, height: 72),
                title: "Today I'm grateful for",
                content: checkInData.gratitudeText.isEmpty ? "—" : checkInData.gratitudeText,
                style: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.label]
            )
            currentY += 88

            // 6. Whoops / Poops side by side
            let halfWidth = (pageSize.width - 3 * margin) / 2
            drawBox(
                in: CGRect(x: margin, y: currentY, width: halfWidth, height: 72),
                title: "Whoops",
                content: checkInData.whoopsText.isEmpty ? "—" : checkInData.whoopsText,
                style: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.label]
            )
            drawBox(
                in: CGRect(x: margin + halfWidth + margin, y: currentY, width: halfWidth, height: 72),
                title: "Poops",
                content: checkInData.poopsText.isEmpty ? "—" : checkInData.poopsText,
                style: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.label]
            )
            currentY += 88

            // 7. Looking forward
            drawBox(
                in: CGRect(x: margin, y: currentY, width: pageSize.width - 2 * margin, height: 56),
                title: "Soon I look forward to",
                content: checkInData.lookForwardTo.isEmpty ? "—" : checkInData.lookForwardTo,
                style: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.label]
            )
        }

        return data
    }

    /// Writes PDF data to a temporary file and returns the file URL for sharing.
    static func writeToTemporaryFile(data: Data, filename: String = "weekly-wrapup.pdf") -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }
}

// MARK: - Drawing helpers

private func drawLogo(in rect: CGRect) {
    let config = UIImage.SymbolConfiguration(pointSize: min(rect.width, rect.height) * 0.6, weight: .medium)
    let image = UIImage(systemName: "camera.fill", withConfiguration: config)?
        .withTintColor(UIColor.systemTeal, renderingMode: .alwaysOriginal)
    image?.draw(in: rect)
}

private func drawBox(in rect: CGRect, title: String, content: String, style: [NSAttributedString.Key: Any]) {
    let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
    UIColor.systemGray5.setFill()
    path.fill()

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.boldSystemFont(ofSize: 12),
        .foregroundColor: UIColor.label
    ]
    let titleRect = CGRect(x: rect.minX + 8, y: rect.minY + 6, width: rect.width - 16, height: 18)
    (title as NSString).draw(in: titleRect, withAttributes: titleAttributes)

    let contentRect = CGRect(x: rect.minX + 8, y: rect.minY + 26, width: rect.width - 16, height: rect.height - 32)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byWordWrapping
    paragraphStyle.lineSpacing = 2
    var contentStyle = style
    contentStyle[.paragraphStyle] = paragraphStyle
    let attributed = NSAttributedString(string: content, attributes: contentStyle)
    attributed.draw(in: contentRect)
}
