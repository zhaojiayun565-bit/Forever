import UIKit
import UserNotifications
import WidgetKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        UNUserNotificationCenter.current().delegate = self

        // Request permission to send notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }

        return true
    }

    // Fires when Apple successfully grants a Device Token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Convert the binary token data to a readable hex string
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("📱 APNs Device Token: \(token)")

        // Send it to Supabase
        Task {
            do {
                try await SupabaseManager.shared.updateDeviceToken(token)
                print("✅ Device Token saved to Supabase")
            } catch {
                print("🚨 Failed to save Device Token: \(error)")
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🚨 Failed to register for APNs: \(error)")
    }

    // 🔥 THE MAGIC METHOD: This fires when a silent push is received in the background
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        print("👻 Silent Push Received!")

        if let defaults = UserDefaults(suiteName: "group.forever.widget") {
            // Catch Note URL
            if let noteUrl = userInfo["note_url"] as? String {
                print("📥 Catching new note URL: \(noteUrl)")
                defaults.set(noteUrl, forKey: "partnerNoteUrl")
            }
            
            // Catch Lock Screen Message
            if let message = userInfo["latest_message"] as? String {
                print("📥 Catching new lock screen message: \(message)")
                defaults.set(message, forKey: "partnerMessage")
            }
        }

        // Reload the widget now that new data is saved
        WidgetCenter.shared.reloadAllTimelines()

        completionHandler(.newData)
    }
}
