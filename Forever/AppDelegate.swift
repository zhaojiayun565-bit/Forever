import UIKit
import UserNotifications
import WidgetKit

extension Notification.Name {
    /// Posted when a push or widget tap should route the user into the shared drawing board.
    static let openDrawingBoard = Notification.Name("openDrawingBoard")
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
            Self.syncWidgetDefaults(from: userInfo)
            WidgetCenter.shared.reloadAllTimelines()
        }
        completionHandler(.newData)
    }

    // Allow notifications to show as banners even when the app is open
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Self.syncWidgetDefaults(from: notification.request.content.userInfo)
        WidgetCenter.shared.reloadAllTimelines()
        completionHandler([.banner, .sound, .badge])
    }

    /// Routes a tapped notification into the drawing board when the payload requests it.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if userInfo["route"] as? String == "drawingboard" {
            Task { @MainActor in
                NotificationCenter.default.post(name: .openDrawingBoard, object: nil)
            }
        }
        completionHandler()
    }

    /// Writes partner note/message from a push payload into the App Group so widget reloads fetch fresh data.
    private static func syncWidgetDefaults(from userInfo: [AnyHashable: Any]) {
        guard let defaults = UserDefaults(suiteName: AppGroup.suiteName) else { return }
        if let noteUrl = userInfo["note_url"] as? String, !noteUrl.isEmpty {
            defaults.set(noteUrl, forKey: "partnerNoteUrl")
        }
        if let message = userInfo["latest_message"] as? String, !message.isEmpty {
            defaults.set(message, forKey: "partnerMessage")
        }
    }
}
