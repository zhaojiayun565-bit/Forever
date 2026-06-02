import Foundation
import UIKit
import UserNotifications

/// Handles notification permission at paywall and remote push registration.
@MainActor
enum NotificationAuthorizationManager {
    private static let didRequestAtPaywallKey = "didRequestNotificationsAtPaywall"

    /// Requests alert permission at paywall once; falls back to provisional when denied.
    static func requestAtPaywallIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: didRequestAtPaywallKey) else {
            await registerForRemoteIfEligible()
            return
        }

        UserDefaults.standard.set(true, forKey: didRequestAtPaywallKey)

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted {
                await registerForRemoteIfEligible()
            } else {
                await requestProvisionalAuthorization()
            }
        case .authorized, .provisional, .ephemeral:
            await registerForRemoteIfEligible()
        case .denied:
            await requestProvisionalAuthorization()
        @unknown default:
            await registerForRemoteIfEligible()
        }
    }

    /// Registers for APNs when full or provisional authorization is active.
    static func registerForRemoteIfEligible() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        default:
            break
        }
    }

    private static func requestProvisionalAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.provisional])
        await registerForRemoteIfEligible()
    }
}
