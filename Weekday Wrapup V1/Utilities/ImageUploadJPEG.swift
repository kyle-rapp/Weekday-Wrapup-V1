import UIKit

/// Normalizes and encodes user images as JPEG for Firebase Storage (`image/jpeg` rules).
enum ImageUploadJPEG {
    static let prepareFailedMessage = "We couldn't prepare that image. Try choosing another one."

    private static let defaultCompressionQuality: CGFloat = 0.82

    /// Converts a `UIImage` to JPEG bytes suitable for Storage upload.
    /// - Normalizes EXIF orientation so pixels match display orientation.
    /// - Optionally downscales so the longest edge is at most `maxPixelDimension`.
    static func jpegDataForUpload(
        from image: UIImage,
        compressionQuality: CGFloat = defaultCompressionQuality,
        maxPixelDimension: CGFloat? = 2048
    ) throws -> Data {
        let normalized = normalizeOrientation(image)
        let sized: UIImage
        if let maxPixelDimension {
            sized = resizeIfNeeded(normalized, maxPixel: maxPixelDimension)
        } else {
            sized = normalized
        }

        let quality = min(max(compressionQuality, 0.1), 1.0)
        guard let data = sized.jpegData(compressionQuality: quality), !data.isEmpty else {
            throw prepareError()
        }
        return data
    }

    static func prepareError() -> NSError {
        NSError(
            domain: "ImageUploadJPEG",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: prepareFailedMessage]
        )
    }

    private static func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func resizeIfNeeded(_ image: UIImage, maxPixel: CGFloat) -> UIImage {
        let width = image.size.width
        let height = image.size.height
        let longest = max(width, height)
        guard longest > maxPixel, longest > 0 else { return image }

        let scale = maxPixel / longest
        let newSize = CGSize(width: floor(width * scale), height: floor(height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
