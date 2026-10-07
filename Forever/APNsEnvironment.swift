import Foundation

/// Which APNs environment this build's device tokens belong to.
/// Xcode / development-signed installs embed a provisioning profile with `aps-environment = development`;
/// TestFlight and App Store builds have no embedded profile and use production.
enum APNsEnvironment: String {
    case development
    case production

    static let current: APNsEnvironment = {
        #if targetEnvironment(simulator)
        return .development
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let profile = String(data: data, encoding: .isoLatin1),
              let start = profile.range(of: "<plist"),
              let end = profile.range(of: "</plist>"),
              let plistData = String(profile[start.lowerBound..<end.upperBound]).data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let value = entitlements["aps-environment"] as? String
        else { return .production }
        return value == "development" ? .development : .production
        #endif
    }()
}
