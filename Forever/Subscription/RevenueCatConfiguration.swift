import Foundation

/// RevenueCat identifiers — must match the RevenueCat dashboard and App Store Connect.
enum RevenueCatConfiguration {
    #if DEBUG
    static let apiKey = "test_iMcbsmPOPsVwrQhfcISOcZZfJDu"
    #else
  // Replace with your production public API key before App Store release.
    static let apiKey = "test_iMcbsmPOPsVwrQhfcISOcZZfJDu"
    #endif

    /// Entitlement identifier in RevenueCat (display name: Forever: App for Couples Pro).
    static let proEntitlementID = "pro"

    /// App Store product identifiers.
    enum ProductID {
        static let monthly = "monthly"
        static let yearly = "yearly"
        static let lifetime = "lifetime"
    }

    /// Default offering identifier in RevenueCat (optional; `nil` uses the current offering).
    static let defaultOfferingID: String? = nil

    /// Terms of Service URL for paywall footer (set in AppSupportConfiguration).
    static var termsURL: URL? { AppSupportConfiguration.termsOfServiceURL }

    /// Privacy policy URL for paywall footer (set in AppSupportConfiguration).
    static var privacyURL: URL? { AppSupportConfiguration.privacyPolicyURL }
}
