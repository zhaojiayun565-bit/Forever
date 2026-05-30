import SwiftUI
import UIKit

/// Rasterizes width-normalized drawing strokes into a transparent PNG for the partner note widget.
enum BoardSnapshotRenderer {
    /// Renders `strokes` to PNG data. Coordinates are width-normalized (x in 0...1, y may exceed 1),
    /// so a single uniform scale (the render width) preserves geometry. Height grows to fit the
    /// lowest point. Returns `nil` when there is nothing to draw.
    static func png(strokes: [DrawStroke], width: CGFloat = 1024) -> Data? {
        let points = strokes.flatMap(\.points)
        guard !points.isEmpty else { return nil }

        let maxY = points.map(\.y).max() ?? 1
        let normalizedHeight = min(max(CGFloat(maxY), 1.0), 2.5)
        let size = CGSize(width: width, height: width * normalizedHeight)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1

        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            for stroke in strokes { draw(stroke, in: ctx.cgContext, scale: width) }
        }
        return image.pngData()
    }

    /// Scales normalized coordinates by the render width (uniform on both axes) and strokes the path.
    private static func draw(_ stroke: DrawStroke, in context: CGContext, scale: CGFloat) {
        let points = stroke.points.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
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
}
