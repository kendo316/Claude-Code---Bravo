import SwiftUI
import UserNotifications

@main
struct FindersKeepersApp: App {
    @StateObject private var store = Store()
    @StateObject private var router = Router.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = ReminderTapHandler.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(router)
                .preferredColorScheme(.dark)
                .tint(Color.gold)
                .task { await store.start() }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: store.reload()
                    case .background: store.saveNow()
                    default: break
                    }
                }
        }
    }
}

enum AppTab: Hashable {
    case pile, weekly, more
}

/// Which tab is showing. Shared so a tapped reminder can jump straight to Weekly.
@MainActor
final class Router: ObservableObject {
    static let shared = Router()
    @Published var tab: AppTab = .pile
}
