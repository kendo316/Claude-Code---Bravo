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
                .keepsAwake(store.isReading && store.settings.keepAwakeWhileReading)
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

    private init() {
        #if DEBUG
        if let tab = DebugLaunch.tab { self.tab = tab }
        #endif
    }
}

#if DEBUG
import Photos

/// Launch options used only by the automated screenshot run (tools/simulator_shots.sh).
/// None of this is compiled into the build that goes on a phone through TestFlight.
enum DebugLaunch {
    static var tab: AppTab? {
        switch UserDefaults.standard.string(forKey: "debugTab") {
        case "weekly": .weekly
        case "more": .more
        default: nil
        }
    }
    static var opensLook: Bool { UserDefaults.standard.bool(forKey: "debugLook") }
    static var opensNewest: Bool { UserDefaults.standard.bool(forKey: "debugDetail") }
    static var searchText: String? { UserDefaults.standard.string(forKey: "debugSearch") }

    /// Photos identifiers of the made-up screenshots imported by `importFixturesIfAsked`.
    static var fixtureIDs: [String] { UserDefaults.standard.stringArray(forKey: "debugFixtureIDs") ?? [] }

    /// Moves the test images from Documents/fixtures into Photos, once, and remembers their identifiers
    /// so they count as screenshots even if the simulator does not tag them as such.
    static func importFixturesIfAsked() async {
        guard UserDefaults.standard.bool(forKey: "debugImport") else { return }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("fixtures")
        let files = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !files.isEmpty else { return }
        let created = IdentifierBox()
        try? await PHPhotoLibrary.shared().performChanges {
            for file in files {
                if let id = PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: file)?
                    .placeholderForCreatedAsset?.localIdentifier {
                    created.ids.append(id)
                }
            }
        }
        UserDefaults.standard.set(fixtureIDs + created.ids, forKey: "debugFixtureIDs")
        for file in files { try? FileManager.default.removeItem(at: file) }
    }

    private final class IdentifierBox: @unchecked Sendable {
        var ids: [String] = []
    }
}
#endif
