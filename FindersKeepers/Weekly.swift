import SwiftUI
import Photos

// MARK: - Weekly tab

struct WeeklyView: View {
    @EnvironmentObject var store: Store
    @State private var showReview = false
    @State private var deleting = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer()
                let due = store.dueCount()
                let n = min(due, store.batch)
                Text(due == 0 ? "ALL CAUGHT UP" : "\(n)")
                    .font(.system(size: due == 0 ? 36 : 96, weight: .black))
                    .foregroundStyle(Color.gold)
                Text(due == 0 ? "Nothing waiting. Take more screenshots."
                              : "of your oldest screenshots are waiting. \(due) in the line.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8)).padding(.horizontal, 32)

                if due > 0 {
                    Button("Start the look") { showReview = true }
                        .buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
                        .controlSize(.large)
                }

                if !store.pending.isEmpty {
                    VStack(spacing: 8) {
                        Text("\(store.pending.count) marked for deletion").font(.footnote.bold())
                        Button(role: .destructive) {
                            Task { deleting = true; failed = !(await store.commitDeletes()); deleting = false }
                        } label: {
                            Text(deleting ? "Deleting…" : "Delete them from Photos")
                        }.buttonStyle(.bordered)
                        Text("iOS asks you once. They stay in Recently Deleted for 30 days.")
                            .font(.caption).foregroundStyle(.white.opacity(0.6))
                        if failed { Text("Cancelled. They're still marked.").font(.caption).foregroundStyle(.orange) }
                    }.padding(.top, 8)
                }

                if let d = store.lastReview {
                    Text("Last look: \(d.formatted(date: .abbreviated, time: .omitted))")
                        .font(.footnote).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.wall)
            .navigationTitle("Weekly")
            .fullScreenCover(isPresented: $showReview) { ReviewView() }
        }
    }
}

// MARK: - The look itself

struct ReviewView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [PHAsset] = []
    @State private var index = 0
    @State private var history: [UndoStep] = []
    @State private var img: UIImage?
    @State private var started = false
    @State private var counts = (kept: 0, deleted: 0, later: 0)
    @State private var deleting = false
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.wall.ignoresSafeArea()
            if !started {
                ProgressView().tint(.gold)
            } else if index >= queue.count {
                finished
            } else {
                card(queue[index])
            }
        }
        .onAppear {
            if !started {
                queue = store.reviewQueue()
                started = true
                if let a = queue.first { load(a) }
            }
        }
    }

    // One screenshot at a time

    private func card(_ a: PHAsset) -> some View {
        let c = store.card(a)
        return VStack(spacing: 10) {
            HStack {
                Button { close() } label: { Image(systemName: "xmark") }
                Spacer()
                Text("\(index + 1) / \(queue.count)").font(.footnote.bold()).foregroundStyle(Color.gold)
                Spacer()
                Button { undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(history.isEmpty)
            }.padding(.horizontal)

            ZStack {
                if let img {
                    Image(uiImage: img).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else { ProgressView().tint(.gold) }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 2) {
                Text(c.title.isEmpty ? "Screenshot" : c.title).font(.headline).lineLimit(2)
                let when = a.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? ""
                let meta = [when, Groups.name(c.group), c.snoozes > 0 ? "put off \(c.snoozes)×" : ""]
                    .filter { !$0.isEmpty }.joined(separator: " · ")
                Text(meta).font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)

            HStack(spacing: 10) {
                action("Delete", "trash", .red) { decide { store.markDelete(a) }; counts.deleted += 1 }
                action("Next week", "clock", .gray) { decide { store.snooze(a) }; counts.later += 1 }
                action("Keep", "checkmark", .gold) { decide { store.keep(a) }; counts.kept += 1 }
            }.padding(.horizontal).padding(.bottom, 8)
        }
    }

    private func action(_ t: String, _ icon: String, _ tint: Color, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(t).font(.footnote.bold())
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(tint.opacity(0.9)).foregroundStyle(tint == .gold ? .black : .white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func decide(_ f: () -> UndoStep) {
        history.append(f())
        index += 1
        img = nil
        if index < queue.count { load(queue[index]) } else { store.finishedReview() }
    }

    private func undo() {
        guard let u = history.popLast() else { return }
        store.undo(u)
        index = max(0, index - 1)
        img = nil
        load(queue[index])
        recount()
    }

    private func recount() {
        var k = 0, d = 0, l = 0
        for a in queue.prefix(index) {
            if store.pending.contains(a.localIdentifier) { d += 1 }
            else if store.cards[a.localIdentifier]?.snoozedAt != nil && store.cards[a.localIdentifier]?.decidedAt == nil { l += 1 }
            else { k += 1 }
        }
        counts = (k, d, l)
    }

    private func load(_ a: PHAsset) {
        Task { img = await PhotoLib.image(for: a, size: CGSize(width: 1200, height: 2400)) }
    }

    private func close() {
        if index > 0 { store.finishedReview() }
        dismiss()
    }

    // Summary

    private var finished: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("DONE").font(.system(size: 60, weight: .black)).foregroundStyle(Color.gold)
            Text("\(counts.kept) kept · \(counts.later) next week · \(counts.deleted) to delete")
                .foregroundStyle(.white.opacity(0.85))
            if !store.pending.isEmpty {
                Button(role: .destructive) {
                    Task {
                        deleting = true
                        let ok = await store.commitDeletes()
                        deleting = false; failed = !ok
                        if ok { dismiss() }
                    }
                } label: { Text(deleting ? "Deleting…" : "Delete \(store.pending.count) from Photos") }
                    .buttonStyle(.borderedProminent).tint(.red).controlSize(.large)
                Text("iOS asks once. Recently Deleted keeps them 30 days.")
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
                if failed { Text("Cancelled. They're still marked. Find them in the Weekly tab.").font(.caption).foregroundStyle(.orange) }
            }
            Button("Close") { dismiss() }.padding(.top, 8)
            Spacer()
        }.padding()
    }
}

// MARK: - More

struct MoreView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading") {
                    LabeledContent("Screenshots", value: "\(store.assets.count)")
                    LabeledContent("Read", value: "\(store.readDone)")
                    if store.readDone < store.readTotal {
                        Text("Reading happens while the app is open. Leave it on screen once to catch up.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Read everything again") { store.rereadAll() }
                }
                Section("Weekly look") {
                    Stepper("Look at \(store.batch) at a time", value: $store.batch, in: 5...50, step: 5)
                    Picker("Kept ones come back", selection: $store.resurfaceDays) {
                        Text("Never").tag(0)
                        Text("After 3 months").tag(90)
                        Text("After 6 months").tag(180)
                        Text("After a year").tag(365)
                    }
                    Toggle("Sunday 7 pm reminder", isOn: $store.reminderOn)
                        .onChange(of: store.reminderOn) { _, on in Task { await store.scheduleWeekly(on) } }
                }
                Section("Photos") {
                    Text("Kept screenshots are also added to an album called Finders Keepers. Deleted ones go to Recently Deleted for 30 days. Hidden-album photos are never touched.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Photos access in Settings") {
                        if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.wall)
            .navigationTitle("More")
        }
    }
}
