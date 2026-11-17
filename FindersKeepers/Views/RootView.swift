import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var router: Router

    var body: some View {
        if store.hasAccess {
            TabView(selection: $router.tab) {
                Tab("Pile", systemImage: "square.stack.fill", value: AppTab.pile) {
                    PileView()
                }
                Tab("Weekly", systemImage: "calendar", value: AppTab.weekly) {
                    WeeklyView()
                }
                .badge(store.dueCount)
                Tab("More", systemImage: "ellipsis.circle", value: AppTab.more) {
                    MoreView()
                }
            }
        } else {
            AccessView()
        }
    }
}

extension View {
    /// Holds the screen awake while a backlog is being read, if that setting is on.
    func keepsAwake(_ isOn: Bool) -> some View {
        onChange(of: isOn, initial: true) { _, awake in
            UIApplication.shared.isIdleTimerDisabled = awake
        }
    }
}

/// Shown until the app is allowed to see Photos.
private struct AccessView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "photo.stack")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Finders Keepers")
                .font(.largeTitle.weight(.bold))
            Text("To sort your screenshots, the app needs to see your photos. Everything is read on this iPhone. Nothing is uploaded, and there is no account.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            if store.access == .notDetermined {
                Button("Allow access to Photos") {
                    Task { await store.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button("Open Settings") { openSettings() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Text("Photos access is off for Finders Keepers. Turn it on under Photos, then come back.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
func openSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
}
