import SwiftUI
import UIKit

/// Gill Sans typography used across the Forever app and widget.
enum ForeverFont {
    static let semiboldName = "GillSans-Medium"
    static let regularName = "GillSans"

    static func header(_ style: Font.TextStyle) -> Font {
        custom(semiboldName, style: style)
    }

    static func header(size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        custom(semiboldName, size: size, relativeTo: style)
    }

    static func subheader(_ style: Font.TextStyle) -> Font {
        custom(regularName, style: style)
    }

    static func subheader(size: CGFloat, relativeTo style: Font.TextStyle = .subheadline) -> Font {
        custom(regularName, size: size, relativeTo: style)
    }

    static func cta(_ style: Font.TextStyle) -> Font {
        custom(semiboldName, style: style)
    }

    static func cta(size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        custom(semiboldName, size: size, relativeTo: style)
    }

    static func body(_ style: Font.TextStyle) -> Font {
        custom(regularName, style: style)
    }

    static func body(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        custom(regularName, size: size, relativeTo: style)
    }

    static func caption(_ style: Font.TextStyle = .caption) -> Font {
        custom(regularName, style: style)
    }

    static func footnote(_ style: Font.TextStyle = .footnote) -> Font {
        custom(regularName, style: style)
    }

    static func bold(_ style: Font.TextStyle) -> Font {
        custom(semiboldName, style: style)
    }

    static func bold(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        custom(semiboldName, size: size, relativeTo: style)
    }

    static func emphasis(size: CGFloat, relativeTo style: Font.TextStyle = .caption) -> Font {
        custom(semiboldName, size: size, relativeTo: style)
    }

    /// Applies Gill Sans to navigation bars, tab bar, and text inputs app-wide.
    static func configureGlobalAppearance() {
        configureNavigationBarAppearance()
        configureTabBarAppearance()
        configureTextInputAppearance()
    }

    static func verifyFontsLoaded() {
        assert(UIFont(name: semiboldName, size: 17) != nil, "Missing \(semiboldName) font")
        assert(UIFont(name: regularName, size: 17) != nil, "Missing \(regularName) font")
    }

    private static func configureNavigationBarAppearance() {
        // Scrolled/inline title uses the system bar; large-title scroll edge matches grouped screens (no hairline).
        let inlineAppearance = UINavigationBarAppearance()
        inlineAppearance.configureWithDefaultBackground()
        applyNavigationBarFonts(to: inlineAppearance)

        let largeTitleEdgeAppearance = UINavigationBarAppearance()
        largeTitleEdgeAppearance.configureWithOpaqueBackground()
        largeTitleEdgeAppearance.backgroundColor = .systemGroupedBackground
        largeTitleEdgeAppearance.shadowColor = .clear
        applyNavigationBarFonts(to: largeTitleEdgeAppearance)

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = inlineAppearance
        navigationBar.compactAppearance = inlineAppearance
        navigationBar.scrollEdgeAppearance = largeTitleEdgeAppearance
        navigationBar.compactScrollEdgeAppearance = largeTitleEdgeAppearance
    }

    /// Applies Gill Sans to large and inline navigation bar titles.
    private static func applyNavigationBarFonts(to appearance: UINavigationBarAppearance) {
        if let largeTitleFont = UIFont(name: semiboldName, size: 34) {
            appearance.largeTitleTextAttributes = [
                .font: largeTitleFont,
                .foregroundColor: UIColor.label,
            ]
        }
        if let inlineTitleFont = UIFont(name: semiboldName, size: 17) {
            appearance.titleTextAttributes = [
                .font: inlineTitleFont,
                .foregroundColor: UIColor.label,
            ]
        }
    }

    private static func configureTabBarAppearance() {
        guard let tabFont = UIFont(name: semiboldName, size: 10) else { return }

        let tabAttributes: [NSAttributedString.Key: Any] = [.font: tabFont]
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()

        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = tabAttributes
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = tabAttributes
        tabAppearance.inlineLayoutAppearance.normal.titleTextAttributes = tabAttributes
        tabAppearance.inlineLayoutAppearance.selected.titleTextAttributes = tabAttributes
        tabAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = tabAttributes
        tabAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = tabAttributes

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tabAppearance
        tabBar.scrollEdgeAppearance = tabAppearance
    }

    private static func configureTextInputAppearance() {
        let bodyPointSize = UIFont.preferredFont(forTextStyle: .body).pointSize
        if let inputFont = UIFont(name: regularName, size: bodyPointSize) {
            UITextField.appearance().font = inputFont
            UITextView.appearance().font = inputFont
        }
    }

    private static func custom(_ name: String, style: Font.TextStyle) -> Font {
        Font.custom(name, size: UIFont.preferredFont(forTextStyle: uiTextStyle(style)).pointSize, relativeTo: style)
    }

    private static func custom(_ name: String, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        Font.custom(name, size: size, relativeTo: style)
    }

    private static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
}
