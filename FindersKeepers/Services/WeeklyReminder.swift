import UserNotifications

/// The weekly nudge. A local notification: scheduled on the phone, no server involved.
enum WeeklyReminder {
    private static let identifier = "weekly-look"

    /// Returns false when notifications are not allowed.
    static func schedule(weekday: Int, hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Time for a look"
        content.body = "Your oldest screenshots are waiting. Keep, delete, or next week."
        content.sound = .default

        var when = DateComponents()
        when.weekday = weekday
        when.hour = hour
        when.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)

        cancel()
        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            return true
        } catch {
            return false
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

/// Opens the Weekly tab when the reminder is tapped.
final class ReminderTapHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderTapHandler()

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { Router.shared.tab = .weekly }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
