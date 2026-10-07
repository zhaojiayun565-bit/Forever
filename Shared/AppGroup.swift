import Foundation

/// The App Group shared by the app and its widget extension.
nonisolated enum AppGroup {
    static let identifier = "group.com.jiayunzhao.Forever"

    /// Shared defaults read by the widgets; nil only if the entitlement is missing.
    static var defaults: UserDefaults? { UserDefaults(suiteName: identifier) }

    /// Shared container directory for files such as cached avatars.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static let pendingDeviceTokenKey = "pendingDeviceToken"
    static let myAvatarFileName = "my-avatar.jpg"
    static let partnerAvatarFileName = "partner-avatar.jpg"
    static let pendingOnboardingMemoryFileName = "pending-onboarding-memory.jpg"
    static let pendingOnboardingMemoryMetadataKey = "pendingOnboardingMemory"
}

/// UserDefaults keys written by the main app and read by widget extensions.
nonisolated enum WidgetDefaultsKey {
    static let partnerDistance = "partnerDistance"
    static let partnerLatitude = "partnerLatitude"
    static let partnerLongitude = "partnerLongitude"
    static let myLatitude = "myLatitude"
    static let myLongitude = "myLongitude"
    static let partnerNoteUrl = "partnerNoteUrl"
    static let partnerMessage = "partnerMessage"
    static let partnerLocationUpdatedAt = "partnerLocationUpdatedAt"
    static let partnerName = "partnerName"
    static let myName = "myName"
    static let myMessage = "myMessage"
    static let distanceUnit = "distanceUnit"
    static let anniversaryDate = "anniversaryDate"
    static let myAvatarUrl = "myAvatarUrl"
    static let partnerAvatarUrl = "partnerAvatarUrl"
    static let myAvatarCachedUrl = "myAvatarCachedUrl"
    static let partnerAvatarCachedUrl = "partnerAvatarCachedUrl"
}
