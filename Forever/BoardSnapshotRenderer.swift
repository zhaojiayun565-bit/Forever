import SwiftUI
import UIKit

/// Rasterizes width-normalized drawing strokes for the partner widget and shared archive.
enum BoardSnapshotRenderer {
    private static let renderWidth: CGFloat = 1024

    /// Centered-square flatten (wallpaper + strokes) matching the board's center area, for the
    /// Partner Note widget. Strokes may be empty to send a background-only image.
    static func widgetSquare(strokes: [DrawStroke], wallpaper: UIImage?, boardSize: CGSize) -> Data? {
        guard boardSize.width > 0, boardSize.height > 0 else { return nil }

        let side = renderWidth
        // Board height in width-normalized units; the center square spans the full width.
        let aspect = boardSize.height / boardSize.width
        // Top of the centered square in width-normalized units.
        let offsetY = (aspect - 1) / 2
        // Full board rect within the square render space; the square clips out the center.
        let boardRect = CGRect(x: 0, y: -offsetY * side, width: side, height: side * aspect)

        let image = render(
            strokes: strokes,
            size: CGSize(width: side, height: side),
            scale: side,
            offset: CGPoint(x: 0, y: offsetY),
            opaque: true
        ) { context, squareRect in
            if let wallpaper {
                drawAspectFill(wallpaper, in: boardRect, clipTo: squareRect, context: context)
            } else {
                drawDefaultGradient(in: boardRect, context: context)
            }
        }
        return image.jpegData(compressionQuality: 0.88)
    }

    /// Full-board capture with wallpaper (or gradient fallback) for the shared archive.
    static func archiveJPEG(strokes: [DrawStroke], wallpaper: UIImage?, boardSize: CGSize) -> Data? {
        guard !strokes.isEmpty, boardSize.width > 0, boardSize.height > 0 else { return nil }

        let aspect = boardSize.height / boardSize.width
        let size = CGSize(width: renderWidth, height: renderWidth * aspect)

        let image = render(strokes: strokes, size: size, scale: renderWidth, offset: .zero) { context, rect in
            if let wallpaper {
                drawAspectFill(wallpaper, in: rect, context: context)
            } else {
                drawDefaultGradient(in: rect, context: context)
            }
        }
        return image.jpegData(compressionQuality: 0.88)
    }

    // MARK: - Core render

    private static func render(
        strokes: [DrawStroke],
        size: CGSize,
        scale: CGFloat,
        offset: CGPoint,
        opaque: Bool = false,
        background: (CGContext, CGRect) -> Void
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = opaque
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let ctx = rendererContext.cgContext
            let rect = CGRect(origin: .zero, size: size)
            background(ctx, rect)
            for stroke in strokes {
                draw(stroke, in: ctx, scale: scale, offset: offset)
            }
        }
    }

    /// Scales normalized coordinates by render width, subtracting crop offset for widget crops.
    private static func draw(_ stroke: DrawStroke, in context: CGContext, scale: CGFloat, offset: CGPoint) {
        let points = stroke.points.map {
            CGPoint(x: ($0.x - offset.x) * scale, y: ($0.y - offset.y) * scale)
        }
        let lineWidth = max(1, CGFloat(stroke.width) * scale)
        let color = UIColor(Color(hexString: stroke.colorHex)).cgColor

        guard points.count > 1 else {
            if let dot = points.first {
                let r = lineWidth / 2
                context.setFillColor(color)
                context.fillEllipse(in: CGRect(x: dot.x - r, y: dot.y - r, width: lineWidth, height: lineWidth))
            }
            return
        }

        context.setStrokeColor(color)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: points[0])
        for point in points.dropFirst() { context.addLine(to: point) }
        context.strokePath()
    }

    /// Aspect-fills `image` into `rect`, matching the on-screen board background. When `clipRect`
    /// is provided the visible area is clipped to it (used to crop the center square of the board).
    private static func drawAspectFill(_ image: UIImage, in rect: CGRect, clipTo clipRect: CGRect? = nil, context: CGContext) {
        guard let cg = image.cgImage else { return }
        let imageAspect = CGFloat(cg.width) / CGFloat(cg.height)
        let rectAspect = rect.width / rect.height

        var drawRect = rect
        if imageAspect > rectAspect {
            let scaledWidth = rect.height * imageAspect
            drawRect = CGRect(x: rect.midX - scaledWidth / 2, y: rect.minY, width: scaledWidth, height: rect.height)
        } else {
            let scaledHeight = rect.width / imageAspect
            drawRect = CGRect(x: rect.minX, y: rect.midY - scaledHeight / 2, width: rect.width, height: scaledHeight)
        }
        context.saveGState()
        context.clip(to: clipRect ?? rect)
        // UIImage.draw respects UIKit's flipped renderer context; CGContext.draw would mirror the photo.
        image.draw(in: drawRect)
        context.restoreGState()
    }

    /// Default lock-screen gradient when no custom wallpaper is set.
    private static func drawDefaultGradient(in rect: CGRect, context: CGContext) {
        let colors = [
            UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1).cgColor,
            UIColor.black.cgColor
        ] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) else { return }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
    }
}
