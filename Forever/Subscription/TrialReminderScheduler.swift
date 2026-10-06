import Foundation
import RevenueCat
import UserNotifications

/// Keeps a local "trial ending soon" reminder in sync with the Pro entitlement (the paywall promises it).
enum TrialReminderScheduler {
    private static let identifier = "forever.trial-ending-reminder"
    private static let preferredLeadTime: TimeInterval = 2 * 24 * 60 * 60
    private static let fallbackLeadTime: TimeInterval = 12 * 60 * 60

    /// Schedules the reminder for an active, renewing trial; removes it otherwise.
    static func sync(with entitlement: EntitlementInfo?) {
        let center = UNUserNotificationCenter.current()
        guard let entitlement,
              entitlement.isActive,
              entitlement.periodType == .trial,
              entitlement.willRenew,
              let trialEnd = entitlement.expirationDate,
              let fireDate = reminderDate(before: trialEnd) else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Your free trial ends soon"
        content.body = "Your Forever trial ends on \(trialEnd.formatted(date: .abbreviated, time: .omitted)). You can manage your subscription in Settings anytime."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    /// Two days before the trial ends, or 12 hours before for short trials; nil if already too late.
    private static func reminderDate(before trialEnd: Date) -> Date? {
        let minimumDelay: TimeInterval = 60
        for leadTime in [preferredLeadTime, fallbackLeadTime] {
            let candidate = trialEnd.addingTimeInterval(-leadTime)
            if candidate.timeIntervalSinceNow > minimumDelay { return candidate }
        }
        return nil
    }
}
