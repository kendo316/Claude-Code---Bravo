import SwiftUI
import UserNotifications

extension Notification.Name {
    static let openWeekly = Notification.Name("openWeekly")
}

/// Handles taps on the Sunday notification.
final class NotifDelegate: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        UserDefaults.standard.set(true, forKey: "openWeekly")
        NotificationCenter.default.post(name: .openWeekly, object: nil)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

let notifDelegate = NotifDelegate()

@main
struct FindersKeepersApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var phase

    init() {
        UNUserNotificationCenter.current().delegate = notifDelegate
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .task { await store.bootstrap() }
                .onChange(of: phase) { _, p in
                    if p == .active { store.becameActive() } else { store.becameInactive() }
                }
        }
    }
}
