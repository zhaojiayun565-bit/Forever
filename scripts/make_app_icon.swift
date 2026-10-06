// Renders the 1024px opaque app icon (splash heart on splash background).
// Usage: swift scripts/make_app_icon.swift Forever/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
// Custom heart path on purpose: SF Symbols may not be used in app icons.
import SwiftUI
import AppKit

struct Heart: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var path = Path()
        path.move(to: p(0.455, 0.935))
        path.addCurve(to: p(0.0, 0.33), control1: p(0.25, 0.77), control2: p(0.0, 0.58))
        path.addCurve(to: p(0.27, 0.02), control1: p(0.0, 0.13), control2: p(0.12, 0.02))
        path.addCurve(to: p(0.5, 0.15), control1: p(0.39, 0.02), control2: p(0.46, 0.08))
        path.addCurve(to: p(0.73, 0.02), control1: p(0.54, 0.08), control2: p(0.61, 0.02))
        path.addCurve(to: p(1.0, 0.33), control1: p(0.88, 0.02), control2: p(1.0, 0.13))
        path.addCurve(to: p(0.545, 0.935), control1: p(1.0, 0.58), control2: p(0.75, 0.77))
        path.addQuadCurve(to: p(0.455, 0.935), control: p(0.5, 0.975))
        path.closeSubpath()
        return path
    }
}

struct Icon: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.04, blue: 0.14),
                    Color(red: 0.12, green: 0.06, blue: 0.22),
                    Color(red: 0.28, green: 0.10, blue: 0.24)
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.45, blue: 0.62).opacity(0.40),
                    Color(red: 0.85, green: 0.35, blue: 0.55).opacity(0.12),
                    .clear
                ],
                center: .init(x: 0.5, y: 0.58), startRadius: 20, endRadius: 520
            )
            Heart()
                .fill(LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.55, blue: 0.72),
                        Color(red: 0.95, green: 0.35, blue: 0.55),
                        Color(red: 0.72, green: 0.32, blue: 0.82)
                    ],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 560, height: 500)
                .shadow(color: Color(red: 1, green: 0.3, blue: 0.55).opacity(0.32), radius: 70, y: 24)
                .offset(y: 16)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor func render(to path: String) {
    let renderer = ImageRenderer(content: Icon())
    renderer.scale = 1
    guard let image = renderer.cgImage else { fatalError("render failed") }
    let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

MainActor.assumeIsolated { render(to: CommandLine.arguments[1]) }
