import Photos
import SwiftUI
import UserNotifications

struct Upcoming: Identifiable {
    let card: Card
    let date: Date
    var id: String { card.id }
}

struct UndoStep {
    let id: String
    let prevCard: Card?
    let wasPending: Bool
    let wasKept: Bool
}

@MainActor
final class Store: ObservableObject {
    @Published var auth: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var assets: [PHAsset] = []            // oldest first
    @Published var cards: [String: Card] = [:]
    @Published var pending: Set<String> = []         // marked Delete, waiting for the one confirmation
    @Published var lastReview: Date?
    @Published var reading = false
    @Published var readTotal = 0
    @Published var readDone = 0

    @Published var batch: Int { didSet { UserDefaults.standard.set(batch, forKey: "batch") } }
    @Published var resurfaceDays: Int { didSet { UserDefaults.standard.set(resurfaceDays, forKey: "resurface") } }
    @Published var reminderOn: Bool { didSet { UserDefaults.standard.set(reminderOn, forKey: "reminder") } }

    private var byID: [String: PHAsset] = [:]
    private var readTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var gen = 0

    init() {
        let d = UserDefaults.standard
        batch = d.object(forKey: "batch") as? Int ?? 25
        resurfaceDays = d.object(forKey: "resurface") as? Int ?? 180
        reminderOn = d.object(forKey: "reminder") as? Bool ?? true
        load()
    }

    var canRead: Bool { auth == .authorized || auth == .limited }

    // MARK: Lifecycle

    func bootstrap() async {
        if auth == .notDetermined {
            auth = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        reload()
        startReading()
        if reminderOn { await scheduleWeekly(true) }
    }

    func requestAccess() async {
        auth = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        reload()
        startReading()
    }

    func becameActive() {
        auth = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        reload()
        startReading()
    }

    func becameInactive() {
        gen += 1
        readTask?.cancel()
        readTask = nil
        reading = false
        saveNow()
    }

    // MARK: Screenshots from Photos

    func reload() {
        guard canRead else { return }
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "(mediaSubtypes & %ld) != 0", Int(PHAssetMediaSubtype.photoScreenshot.rawValue))
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let r = PHAsset.fetchAssets(with: .image, options: o)
        var a: [PHAsset] = []
        a.reserveCapacity(r.count)
        r.enumerateObjects { x, _, _ in a.append(x) }
        assets = a
        byID = Dictionary(uniqueKeysWithValues: a.map { ($0.localIdentifier, $0) })

        if auth == .authorized {   // only prune when we can see everything
            let gone = cards.keys.filter { byID[$0] == nil }
            for k in gone { cards[k] = nil }
            pending = pending.filter { byID[$0] != nil }
        }
        readTotal = assets.count
        readDone = assets.filter { cards[$0.localIdentifier]?.read == true }.count
    }

    func asset(_ id: String) -> PHAsset? { byID[id] }

    // MARK: Reading (OCR + title + group), oldest first, review queue first

    func startReading() {
        guard readTask == nil, canRead else { return }
        gen += 1
        let g = gen
        reading = true
        readTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let a = self.nextUnread() else { break }
                await self.readOne(a)
            }
            guard let self else { return }
            if self.gen == g { self.reading = false; self.readTask = nil }
        }
    }

    private func isRead(_ a: PHAsset) -> Bool { cards[a.localIdentifier]?.read == true }

    private func nextUnread() -> PHAsset? {
        if let a = reviewQueue().first(where: { !isRead($0) }) { return a }
        return assets.first { !isRead($0) && !pending.contains($0.localIdentifier) }
    }

    private func readOne(_ a: PHAsset) async {
        var c = cards[a.localIdentifier] ?? Card(id: a.localIdentifier)
        if let img = await PhotoLib.image(for: a, size: PHImageManagerMaximumSize, mode: .default),
           let cg = img.cgImage {
            let e = await Reader.read(cg)
            c.title = e.title; c.summary = e.summary; c.group = e.group
            c.text = e.text; c.address = e.address; c.links = e.links; c.dates = e.dates
        } else {
            c.title = "Screenshot"
        }
        c.read = true
        cards[c.id] = c
        readDone = assets.filter { cards[$0.localIdentifier]?.read == true }.count
        scheduleSave()
    }

    func rereadAll() {
        for k in cards.keys { cards[k]?.read = false }
        readDone = 0
        scheduleSave()
        startReading()
    }

    // MARK: Weekly look

    func reviewQueue() -> [PHAsset] {
        let now = Date()
        let q = assets.filter { a in
            let id = a.localIdentifier
            if pending.contains(id) { return false }
            let c = cards[id]
            if let s = c?.snoozedAt, now.timeIntervalSince(s) < 7 * 86400 { return false }
            if let d = c?.decidedAt {
                return resurfaceDays > 0 && now.timeIntervalSince(d) > Double(resurfaceDays) * 86400
            }
            return true
        }
        return Array(q.prefix(batch))
    }

    func dueCount() -> Int {
        let now = Date()
        return assets.filter { a in
            let id = a.localIdentifier
            if pending.contains(id) { return false }
            let c = cards[id]
            if let s = c?.snoozedAt, now.timeIntervalSince(s) < 7 * 86400 { return false }
            if let d = c?.decidedAt { return resurfaceDays > 0 && now.timeIntervalSince(d) > Double(resurfaceDays) * 86400 }
            return true
        }.count
    }

    func card(_ a: PHAsset) -> Card { cards[a.localIdentifier] ?? Card(id: a.localIdentifier) }

    func keep(_ a: PHAsset) -> UndoStep {
        let u = UndoStep(id: a.localIdentifier, prevCard: cards[a.localIdentifier],
                         wasPending: pending.contains(a.localIdentifier), wasKept: cards[a.localIdentifier]?.decidedAt != nil)
        var c = card(a); c.decidedAt = Date(); c.snoozedAt = nil
        cards[c.id] = c
        Task { await PhotoLib.setKept(a, true) }
        scheduleSave()
        return u
    }

    func snooze(_ a: PHAsset) -> UndoStep {
        let u = UndoStep(id: a.localIdentifier, prevCard: cards[a.localIdentifier],
                         wasPending: pending.contains(a.localIdentifier), wasKept: false)
        var c = card(a); c.snoozedAt = Date(); c.snoozes += 1
        cards[c.id] = c
        scheduleSave()
        return u
    }

    func markDelete(_ a: PHAsset) -> UndoStep {
        let u = UndoStep(id: a.localIdentifier, prevCard: cards[a.localIdentifier],
                         wasPending: pending.contains(a.localIdentifier), wasKept: false)
        pending.insert(a.localIdentifier)
        scheduleSave()
        return u
    }

    func undo(_ u: UndoStep) {
        cards[u.id] = u.prevCard
        if u.wasPending { pending.insert(u.id) } else { pending.remove(u.id) }
        if let a = byID[u.id], !u.wasKept { Task { await PhotoLib.setKept(a, false) } }
        scheduleSave()
    }

    func unmarkDelete(_ id: String) { pending.remove(id); scheduleSave() }

    /// One system prompt covers the whole batch. Photos keeps them 30 days in Recently Deleted.
    func commitDeletes() async -> Bool {
        let list = assets.filter { pending.contains($0.localIdentifier) }
        guard !list.isEmpty else { return true }
        let ok = await PhotoLib.delete(list)
        if ok {
            for a in list { cards[a.localIdentifier] = nil }
            pending = []
            reload()
            scheduleSave()
        }
        return ok
    }

    func finishedReview() { lastReview = Date(); scheduleSave() }

    // MARK: Pile helpers

    func upcoming() -> [Upcoming] {
        let now = Date().addingTimeInterval(-86400)
        let soon = Date().addingTimeInterval(86400 * 45)
        var out: [Upcoming] = []
        for c in cards.values where !pending.contains(c.id) {
            if let d = c.dates.first(where: { $0 > now && $0 < soon }) { out.append(Upcoming(card: c, date: d)) }
        }
        return out.sorted { $0.date < $1.date }
    }

    func search(_ q: String, group: String?) -> [PHAsset] {
        let toks = q.lowercased().split(separator: " ").map(String.init)
        return assets.reversed().filter { a in
            let id = a.localIdentifier
            if pending.contains(id) { return false }
            let c = cards[id]
            if let g = group, c?.group != g { return false }
            if toks.isEmpty { return true }
            guard let c else { return false }
            let h = c.haystack
            return toks.allSatisfy { h.contains($0) }
        }
    }

    func binding(_ id: String, _ kp: WritableKeyPath<Card, String>) -> Binding<String> {
        Binding(
            get: { self.cards[id]?[keyPath: kp] ?? "" },
            set: { v in
                var c = self.cards[id] ?? Card(id: id)
                c[keyPath: kp] = v
                self.cards[id] = c
                self.scheduleSave()
            })
    }

    // MARK: Sunday notification

    func scheduleWeekly(_ on: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly"])
        guard on else { return }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        var d = DateComponents()
        d.weekday = 1; d.hour = 19; d.minute = 0     // Sunday, 7 pm
        let content = UNMutableNotificationContent()
        content.title = "Screenshot look"
        content.body = "Your oldest screenshots are waiting. Keep, delete, or next week."
        content.sound = .default
        let req = UNNotificationRequest(identifier: "weekly", content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: d, repeats: true))
        try? await center.add(req)
    }

    // MARK: Persistence (a JSON file in the app's own storage)

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("fk.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        cards = s.cards
        pending = Set(s.pending)
        lastReview = s.lastReview
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            if !Task.isCancelled { self?.saveNow() }
        }
    }

    func saveNow() {
        let s = Saved(cards: cards, pending: Array(pending), lastReview: lastReview)
        if let data = try? JSONEncoder().encode(s) { try? data.write(to: fileURL, options: .atomic) }
    }
}
