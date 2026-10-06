import Foundation

/// Centralized support, legal, and subscription URLs for the Me tab and paywall.
enum AppSupportConfiguration {
    static let supportEmail = "jiayun.studio@gmail.com"

    static var contactSupportURL: URL? {
        mailtoURL(subject: "Forever Support")
    }

    static var feedbackEmail: String? = supportEmail
    static var feedbackEmailSubject: String = "Forever App Feedback"

    static let websiteURL = URL(string: "https://forever-couples-iota.vercel.app")!
    static var termsOfServiceURL: URL? = websiteURL.appending(path: "terms")
    static var privacyPolicyURL: URL? = websiteURL.appending(path: "privacy")

    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    /// Builds a mailto URL for share feedback when the email is configured.
    static var feedbackMailtoURL: URL? {
        mailtoURL(subject: feedbackEmailSubject, to: feedbackEmail)
    }

    /// Builds a mailto URL with a prefilled subject.
    private static func mailtoURL(subject: String, to email: String? = supportEmail) -> URL? {
        guard let email else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url
    }
}
