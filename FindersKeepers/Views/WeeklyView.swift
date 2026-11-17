import SwiftUI

/// The front door to the weekly look, and the place to finish deleting.
struct WeeklyView: View {
    @EnvironmentObject private var store: Store
    @State private var isLooking = false
    @State private var isDeleting = false
    @State private var toast: String?
    @AppStorage("hasDeclinedReminder") private var hasDeclinedReminder = false

    var body: some View {
        let due = store.dueCount
        let batch = min(due, store.settings.batchSize)
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if due == 0 {
                        Text("ALL CAUGHT UP")
                            .font(.poster(44))
                            .foregroundStyle(Color.gold)
                            .padding(.top, 60)
                        Text("Nothing is waiting. Go take more screenshots.")
                            .foregroundStyle(Color.quiet)
                    } else {
                        Text("\(batch)")
                            .font(.poster(120))
                            .foregroundStyle(Color.gold)
                            .contentTransition(.numericText())
                            .padding(.top, 36)
                        Text(batch == 1 ? "old screenshot is ready for a look." : "of your oldest screenshots are ready for a look.")
                            .multilineTextAlignment(.center)
                        if due > batch {
                            Text("\(due) are in line altogether.")
                                .font(.footnote)
                                .foregroundStyle(Color.quiet)
                        }
                        Button {
                            Haptics.soft()
                            isLooking = true
                        } label: {
                            Text("Start the look").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(Color.ink)
                        .controlSize(.large)
                        .padding(.top, 6)
                    }

                    if !store.markedForDelete.isEmpty { markedPanel }
                    if !store.settings.reminderOn, !hasDeclinedReminder { reminderOffer }
                    if store.settings.reminderOn, store.remindersBlocked { remindersBlockedNote }

                    if let last = store.lastLookAt {
                        Text("Last look \(last.ago). \(store.looksCompleted) finished so far.")
                            .font(.footnote)
                            .foregroundStyle(Color.quiet)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity)
            }
            .background(Color.wall.ignoresSafeArea())
            .navigationTitle("Weekly")
            .fullScreenCover(isPresented: $isLooking) {
                ReviewView(queue: store.lookQueue())
            }
            .toast($toast)
            #if DEBUG
            .task {
                guard DebugLaunch.opensLook else { return }
                try? await Task.sleep(for: .seconds(2))
                isLooking = true
            }
            #endif
        }
    }

    /// Screenshots chosen for deletion wait here until you confirm once.
    private var markedPanel: some View {
        VStack(spacing: 10) {
            Text("\(store.markedForDelete.count) marked for deletion")
                .font(.headline)
            Text("iOS asks you once for the lot. They then sit in Recently Deleted for 30 days.")
                .font(.footnote)
                .foregroundStyle(Color.quiet)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button("Unmark all") {
                    store.unmarkAll()
                    toast = "Unmarked. Nothing was deleted."
                }
                .buttonStyle(.bordered)
                Button(role: .destructive) {
                    deleteMarked()
                } label: {
                    Text(isDeleting ? "Deleting…" : "Delete from Photos")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isDeleting)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.top, 10)
    }

    /// The weekly nudge is offered here, where it makes sense, instead of at first launch.
    private var reminderOffer: some View {
        VStack(spacing: 10) {
            Text("Want a weekly nudge?")
                .font(.headline)
            Text("One notification, \(store.settings.reminderDescription). Change the day and time under More.")
                .font(.footnote)
                .foregroundStyle(Color.quiet)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button("Not now") { hasDeclinedReminder = true }
                    .buttonStyle(.bordered)
                Button("Remind me") {
                    Haptics.soft()
                    store.settings.reminderOn = true
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Color.ink)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.top, 10)
    }

    private var remindersBlockedNote: some View {
        Button("Notifications are off for this app, so the reminder can't reach you. Open Settings.") {
            openSettings()
        }
        .font(.footnote)
        .multilineTextAlignment(.center)
    }

    private func deleteMarked() {
        isDeleting = true
        Task {
            let deleted = await store.deleteMarked()
            isDeleting = false
            if deleted {
                Haptics.success()
                toast = "Gone. Recently Deleted has them for 30 days."
            } else {
                toast = "Cancelled. They are still marked."
            }
        }
    }
}
