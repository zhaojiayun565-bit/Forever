import CoreLocation
import UIKit
import UserNotifications
import WidgetKit

extension Notification.Name {
    /// Posted when a push or widget tap should route the user into the shared drawing board.
    static let openDrawingBoard = Notification.Name("openDrawingBoard")
    /// Posted when a push should route to the Us tab (daily question).
    static let openHome = Notification.Name("openHome")
    /// Posted when a push should route to the Questions tab.
    static let openQuestions = Notification.Name("openQuestions")
}

/// Shared keys for the App Group used by the widget and push pipeline.
enum AppGroup {
    static let suiteName = "group.com.jiayunzhao.Forever"
    static let pendingDeviceTokenKey = "pendingDeviceToken"
    static let myAvatarFileName = "my-avatar.jpg"
    static let partnerAvatarFileName = "partner-avatar.jpg"
    static let pendingOnboardingMemoryFileName = "pending-onboarding-memory.jpg"
    static let pendingOnboardingMemoryMetadataKey = "pendingOnboardingMemory"
}

/// UserDefaults keys written by the main app and read by widget extensions.
enum WidgetDefaultsKey {
    static let partnerDistance = "partnerDistance"
    static let partnerLatitude = "partnerLatitude"
    static let partnerLongitude = "partnerLongitude"
    static let myLatitude = "myLatitude"
    static let myLongitude = "myLongitude"
    static let partnerNoteUrl = "partnerNoteUrl"
    static let partnerMessage = "partnerMessage"
    static let partnerLocationUpdatedAt = "partnerLocationUpdatedAt"
}

/// Widget kind identifiers matching CoupleWidget target definitions.
enum WidgetKind {
    static let distanceHome = "StatusWidget"
    static let distanceLockScreen = "DistanceLockScreenWidget"
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set the delegate so foreground notifications show up, but DO NOT request authorization here!
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ APNs Device Token: \(token)")
        // Cache so a later sign-in can attach the token to the authenticated user.
        UserDefaults(suiteName: AppGroup.suiteName)?.set(token, forKey: AppGroup.pendingDeviceTokenKey)
        Task { try? await SupabaseManager.shared.updateDeviceToken(token) }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🚨 Failed to register for remote notifications: \(error)")
    }
    
    /// Applies push payload to App Group defaults, then reloads widget timelines.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task { @MainActor in
            let didUpdateLocation = Self.syncWidgetDefaults(from: userInfo)
            Self.reloadWidgets(for: userInfo, didUpdateLocation: didUpdateLocation)
            completionHandler(.newData)
        }
    }

    // Allow notifications to show as banners even when the app is open
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        let didUpdateLocation = Self.syncWidgetDefaults(from: userInfo)
        Self.reloadWidgets(for: userInfo, didUpdateLocation: didUpdateLocation)

        if userInfo["type"] as? String == "location" {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .badge])
    }

    /// Routes a tapped notification into the drawing board when the payload requests it.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            switch userInfo["route"] as? String {
            case "drawingboard":
                NotificationCenter.default.post(name: .openDrawingBoard, object: nil)
            case "home":
                NotificationCenter.default.post(name: .openHome, object: nil)
            case "questions":
                NotificationCenter.default.post(name: .openQuestions, object: nil)
            default:
                break
            }
        }
        completionHandler()
    }

    /// Reloads distance widgets only for silent location pushes; all widgets otherwise.
    private static func reloadWidgets(for userInfo: [AnyHashable: Any], didUpdateLocation: Bool) {
        if userInfo["type"] as? String == "location", didUpdateLocation {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.distanceHome)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.distanceLockScreen)
        } else {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Writes push payload fields into the App Group so widget reloads fetch fresh data.
    @discardableResult
    private static func syncWidgetDefaults(from userInfo: [AnyHashable: Any]) -> Bool {
        guard let defaults = UserDefaults(suiteName: AppGroup.suiteName) else { return false }

        if let noteUrl = userInfo["note_url"] as? String, !noteUrl.isEmpty {
            defaults.set(noteUrl, forKey: WidgetDefaultsKey.partnerNoteUrl)
        }
        if let message = userInfo["latest_message"] as? String, !message.isEmpty {
            defaults.set(message, forKey: WidgetDefaultsKey.partnerMessage)
        }

        guard userInfo["type"] as? String == "location" else { return false }

        guard
            let partnerLat = doubleValue(from: userInfo["partner_latitude"]),
            let partnerLon = doubleValue(from: userInfo["partner_longitude"])
        else {
            return false
        }

        defaults.set(partnerLat, forKey: WidgetDefaultsKey.partnerLatitude)
        defaults.set(partnerLon, forKey: WidgetDefaultsKey.partnerLongitude)
        defaults.set(Date().timeIntervalSince1970, forKey: WidgetDefaultsKey.partnerLocationUpdatedAt)

        if let distance = doubleValue(from: userInfo["partner_distance"]) {
            defaults.set(distance, forKey: WidgetDefaultsKey.partnerDistance)
        } else if
            let myLat = defaults.object(forKey: WidgetDefaultsKey.myLatitude) as? Double,
            let myLon = defaults.object(forKey: WidgetDefaultsKey.myLongitude) as? Double
        {
            let myLocation = CLLocation(latitude: myLat, longitude: myLon)
            let partnerLocation = CLLocation(latitude: partnerLat, longitude: partnerLon)
            let distanceInMiles = myLocation.distance(from: partnerLocation) / 1609.344
            defaults.set(distanceInMiles, forKey: WidgetDefaultsKey.partnerDistance)
        }

        return true
    }

    /// Coerces push payload numbers that may arrive as NSNumber or String.
    private static func doubleValue(from value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        case let double as Double:
            return double
        default:
            return nil
        }
    }
}
