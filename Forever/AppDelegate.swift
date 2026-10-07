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
            Self.applyPushToWidgets(userInfo)
            completionHandler(.newData)
        }
    }

    // Allow notifications to show as banners even when the app is open
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        Self.applyPushToWidgets(userInfo)

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

    /// Writes push payload fields into the App Group and reloads only the widgets they affect.
    @MainActor
    private static func applyPushToWidgets(_ userInfo: [AnyHashable: Any]) {
        guard var writer = WidgetDefaultsWriter() else { return }

        if let noteUrl = userInfo["note_url"] as? String, !noteUrl.isEmpty {
            writer.set(noteUrl, forKey: WidgetDefaultsKey.partnerNoteUrl, affects: [WidgetKind.drawing])
        }
        if let message = userInfo["latest_message"] as? String, !message.isEmpty {
            writer.set(message, forKey: WidgetDefaultsKey.partnerMessage, affects: [WidgetKind.lockScreenMessage, WidgetKind.distanceHome])
        }

        if userInfo["type"] as? String == "location",
           let partnerLat = doubleValue(from: userInfo["partner_latitude"]),
           let partnerLon = doubleValue(from: userInfo["partner_longitude"]) {
            let partnerCoordinate = CLLocationCoordinate2D(latitude: partnerLat, longitude: partnerLon)
            writer.setCoordinate(
                partnerCoordinate,
                latitudeKey: WidgetDefaultsKey.partnerLatitude,
                longitudeKey: WidgetDefaultsKey.partnerLongitude
            )
            let updatedAt = (userInfo["partner_location_updated_at"] as? String).flatMap(parseServerDate) ?? Date()
            writer.set(updatedAt.timeIntervalSince1970, forKey: WidgetDefaultsKey.partnerLocationUpdatedAt, affects: WidgetKind.distance)

            if let miles = doubleValue(from: userInfo["partner_distance"]) ?? distanceFromMyLocation(to: partnerCoordinate, in: writer.defaults) {
                writer.set((miles * 100).rounded() / 100, forKey: WidgetDefaultsKey.partnerDistance, affects: WidgetKind.distance)
            }
        }

        writer.reload()
    }

    /// Miles between our cached location and `coordinate`, when ours is known.
    private static func distanceFromMyLocation(to coordinate: CLLocationCoordinate2D, in defaults: UserDefaults) -> Double? {
        guard let myLat = defaults.object(forKey: WidgetDefaultsKey.myLatitude) as? Double,
              let myLon = defaults.object(forKey: WidgetDefaultsKey.myLongitude) as? Double else { return nil }
        return CLLocation(latitude: myLat, longitude: myLon)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) / 1609.344
    }

    /// Parses Postgres `timestamptz` JSON (ISO 8601, with or without fractional seconds).
    private static func parseServerDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
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
