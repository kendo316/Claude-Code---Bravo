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

/// Shown until the app is allowed to see Photos.
private struct AccessView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("FINDERS\nKEEPERS")
                .font(.poster(56))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.gold)
            Text("To sort your screenshots, the app needs to see your photos. Everything is read on this iPhone. Nothing is uploaded, and there is no account.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.quiet)
                .padding(.horizontal, 32)

            if store.access == .notDetermined {
                Button("Allow access to Photos") {
                    Task { await store.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Color.ink)
                .controlSize(.large)
            } else {
                Button("Open Settings") { openSettings() }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Color.ink)
                    .controlSize(.large)
                Text("Photos access is off for Finders Keepers. Turn it on under Photos, then come back.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.quiet)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.wall.ignoresSafeArea())
    }
}

@MainActor
func openSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
}
