import UIKit

/// JPEG encoding and downscaling that run off the main actor, so large photos don't stall the UI.
nonisolated enum ImageEncoding {
    /// Thrown when an image can't be encoded for upload.
    struct EncodingError: LocalizedError {
        var errorDescription: String? { String(localized: "Could not process the photo.") }
    }

    /// JPEG-encodes `image`, first downscaling so its longest side is at most `maxDimension` when given.
    @concurrent
    static func jpeg(_ image: UIImage, quality: CGFloat, maxDimension: CGFloat? = nil) async throws -> Data {
        let source = maxDimension.map { image.downscaled(toMaxDimension: $0) } ?? image
        guard let data = source.jpegData(compressionQuality: quality) else { throw EncodingError() }
        return data
    }

    /// Re-encodes arbitrary image data as JPEG; returns the input unchanged if it can't be decoded.
    @concurrent
    static func jpeg(from data: Data, quality: CGFloat) async -> Data {
        UIImage(data: data)?.jpegData(compressionQuality: quality) ?? data
    }
}

nonisolated extension UIImage {
    /// Returns a copy whose longest side is at most `maxDimension` (or `self` if already smaller).
    func downscaled(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
