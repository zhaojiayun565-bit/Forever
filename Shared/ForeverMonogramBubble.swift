import SwiftUI
import UIKit

/// Visual treatment for monogram circles across app and widgets.
enum ForeverMonogramStyle {
    case glassDark
    case glassLight
}

/// Premium glass monogram circle with optional profile photo.
struct ForeverMonogramBubble: View {
    let name: String
    var label: String?
    var image: UIImage?
    var size: CGFloat = 52
    var style: ForeverMonogramStyle = .glassDark
    var showsShadow: Bool = false

    private var displayLabel: String {
        label ?? Self.initial(from: name)
    }

    var body: some View {
        monogramContent
            .foreverMonogramChrome(size: size, style: style)
            .shadow(
                color: showsShadow ? .black.opacity(0.25) : .clear,
                radius: showsShadow ? 4 : 0,
                x: 0,
                y: showsShadow ? 2 : 0
            )
    }

    @ViewBuilder
    private var monogramContent: some View {
        ZStack {
            if image == nil {
                Circle()
                    .fill(ForeverMonogramStyle.fillColor(for: style))
            }

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }

            if image == nil {
                Text(displayLabel)
                    .font(ForeverFont.bold(size: size * 0.3, relativeTo: .headline))
                    .foregroundStyle(ForeverMonogramStyle.textColor(for: style))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
    }

    /// First-letter monogram from a display name.
    static func initial(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }
}

extension ForeverMonogramStyle {
    static func strokeColor(for style: ForeverMonogramStyle) -> Color {
        switch style {
        case .glassDark:
            Color.white.opacity(0.85)
        case .glassLight:
            Color.primary.opacity(0.22)
        }
    }

    static func fillColor(for style: ForeverMonogramStyle) -> Color {
        switch style {
        case .glassDark:
            Color.white.opacity(0.12)
        case .glassLight:
            Color.primary.opacity(0.06)
        }
    }

    static func textColor(for style: ForeverMonogramStyle) -> Color {
        switch style {
        case .glassDark:
            .white
        case .glassLight:
            .primary
        }
    }

    static func strokeWidth(for size: CGFloat) -> CGFloat {
        max(1, size * 0.029)
    }
}

extension View {
    /// Applies the shared monogram circle clip and glass ring.
    func foreverMonogramChrome(size: CGFloat, style: ForeverMonogramStyle) -> some View {
        frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(
                        ForeverMonogramStyle.strokeColor(for: style),
                        lineWidth: ForeverMonogramStyle.strokeWidth(for: size)
                    )
            }
    }
}
