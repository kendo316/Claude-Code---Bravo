import SwiftUI

/// Settings, plus a plain account of what the app does with your photos.
struct MoreView: View {
    @EnvironmentObject private var store: Store
    @State private var isConfirmingReread = false
    @State private var isShowingFirst = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Look at \(store.settings.batchSize) at a time", value: $store.settings.batchSize, in: 5...50, step: 5)
                    Picker("Kept ones come back", selection: $store.settings.resurfaceAfterDays) {
                        Text("Never").tag(0)
                        Text("After 3 months").tag(90)
                        Text("After 6 months").tag(180)
                        Text("After a year").tag(365)
                    }
                } header: {
                    Text("Weekly look")
                } footer: {
                    Text("Keep sends a screenshot to the back of the line. This sets how long before it comes round again.")
                }

                Section {
                    Toggle("Remind me every week", isOn: $store.settings.reminderOn)
                    if store.settings.reminderOn {
                        Picker("Day", selection: $store.settings.reminderWeekday) {
                            ForEach(Array(Calendar.current.weekdaySymbols.enumerated()), id: \.offset) { index, name in
                                Text(name).tag(index + 1)
                            }
                        }
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                        if store.remindersBlocked {
                            Button("Notifications are off for this app. Open Settings.") { openSettings() }
                                .font(.footnote)
                        }
                    }
                } header: {
                    Text("Reminder")
                }

                Section {
                    LabeledContent("Screenshots", value: "\(store.screenshots.count)")
                    LabeledContent("Words read", value: "\(store.readCount)")
                    LabeledContent("Titles written", value: "\(store.titledCount)")
                    Toggle("Keep the screen awake while reading", isOn: $store.settings.keepAwakeWhileReading)
                    Button("Read everything again") { isConfirmingReread = true }
                } header: {
                    Text("Reading")
                } footer: {
                    Text(OnDeviceModel.isAvailable
                         ? "Reading happens while the app is open. Words come first, so search works early. Titles and groups follow, written by Apple Intelligence on this iPhone. For a big backlog, turn on the switch above and leave the phone on its charger."
                         : "Apple Intelligence is not available right now, so titles come from the first line of text. Better ones are written on their own once it is back.")
                }

                Section {
                    Button("Photos access in Settings") { openSettings() }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("No account, no server, no tracking. Nothing leaves this iPhone unless you share it. Kept screenshots are also added to an album called \(PhotoLibrary.keptAlbumTitle). Deleted ones go to Recently Deleted for 30 days. To lock the app with Face ID, touch and hold its icon on the Home Screen and choose Require Face ID.")
                }

                Section {
                    EmptyView()
                } footer: {
                    Text("Finders Keepers \(version)")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onLongPressGesture {
                            guard !store.screenshots.isEmpty else { return }
                            Haptics.success()
                            isShowingFirst = true
                        }
                }
            }
            .navigationTitle("More")
            .confirmationDialog("Read every screenshot again?", isPresented: $isConfirmingReread, titleVisibility: .visible) {
                Button("Read again") { store.readEverythingAgain() }
            } message: {
                Text("Titles and groups you changed by hand are left alone. Your notes and keep decisions are too.")
            }
            .sheet(isPresented: $isShowingFirst) { FirstScreenshotView() }
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// The reminder's hour and minute, presented as a time for the picker.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                let parts = DateComponents(hour: store.settings.reminderHour, minute: store.settings.reminderMinute)
                return Calendar.current.date(from: parts) ?? Date()
            },
            set: { newTime in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                var updated = store.settings
                updated.reminderHour = parts.hour ?? 19
                updated.reminderMinute = parts.minute ?? 0
                store.settings = updated
            }
        )
    }
}

/// A small surprise: press and hold the version number on the More tab.
private struct FirstScreenshotView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Text("Where it all began")
                .font(.title2.weight(.bold))
                .padding(.top, 28)
            if let first = store.screenshots.first {
                if let taken = first.creationDate {
                    Text("The oldest screenshot still on this phone. \(taken.shortDay), \(taken.ago).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Screenshot(asset: first)
            }
            Button("Close") { dismiss() }
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
