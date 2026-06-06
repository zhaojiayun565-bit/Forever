import Foundation

/// Centralized support, legal, and subscription URLs for the Me tab and paywall.
enum AppSupportConfiguration {
    /// Set when you have the support page or mailto link.
    static var contactSupportURL: URL? = nil

    /// Set when you have the feedback email.
    static var feedbackEmail: String? = nil
    static var feedbackEmailSubject: String = "Forever App Feedback"

    /// Set when legal pages are live (e.g. https://foreverapp.io/terms).
    static var termsOfServiceURL: URL? = nil
    static var privacyPolicyURL: URL? = nil

    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    /// Builds a mailto URL for share feedback when the email is configured.
    static var feedbackMailtoURL: URL? {
        guard let feedbackEmail else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: feedbackEmailSubject)
        ]
        return components.url
    }
}
