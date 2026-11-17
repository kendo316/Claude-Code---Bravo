import Photos
import SwiftUI

/// The three answers in a weekly look.
enum Verdict {
    case keep, delete, later
}

/// What is needed to take one decision back.
struct UndoStep {
    let id: String
    let cardBefore: Card?
    let wasMarkedForDelete: Bool
    let addedToAlbum: Bool
}

/// A screenshot with a day still ahead of it.
struct Upcoming: Identifiable {
    let card: Card
    let date: Date
    var id: String { card.id }
}

/// The app's single source of truth: the screenshots in Photos plus what we remember about each.
@MainActor
final class Store: ObservableObject {
    @Published private(set) var access = PhotoLibrary.access
    /// Oldest first.
    @Published private(set) var screenshots: [PHAsset] = []
    @Published private(set) var cards: [String: Card] = [:]
    /// Chosen for deletion, waiting for the single iOS confirmation.
    @Published private(set) var markedForDelete: Set<String> = []
    @Published private(set) var lastLookAt: Date?
    @Published private(set) var looksCompleted = 0
    @Published private(set) var readCount = 0
    @Published private(set) var isReading = false
    @Published private(set) var remindersBlocked = false
    @Published var settings = Settings() {
        didSet { if settings != oldValue { settingsChanged(from: oldValue) } }
    }

    private let file = CardFile()
    private var orderedIDs: [String] = []
    private var assetsByID: [String: PHAsset] = [:]
    private var searchTextByID: [String: String] = [:]
    private var couldNotRead: Set<String> = []
    private var couldNotTitle: Set<String> = []
    private var takenOutOfAlbum: Set<String> = []
    private var observer: LibraryObserver?
    private var readTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var albumWork: Task<Void, Never>?

    init() {
        let saved = file.load()
        cards = Dictionary(saved.cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        markedForDelete = Set(saved.markedForDelete)
        lastLookAt = saved.lastLookAt
        looksCompleted = saved.looksCompleted
        settings = saved.settings
    }

    var hasAccess: Bool {
        access == .authorized || access == .limited
    }

    // MARK: - Starting up

    func start() async {
        if access == .notDetermined {
            access = await PhotoLibrary.requestAccess()
        }
        reload()
        await applyReminder()
    }

    func requestAccess() async {
        access = await PhotoLibrary.requestAccess()
        reload()
    }

    /// Re-reads the list of screenshots from Photos. Cheap, and safe to call often.
    func reload() {
        let current = PhotoLibrary.access
        if access != current { access = current }
        guard hasAccess else { return }
        if observer == nil {
            observer = LibraryObserver { [weak self] in self?.reload() }
        }
        screenshots = PhotoLibrary.screenshots()
        orderedIDs = screenshots.map(\.localIdentifier)
        assetsByID = Dictionary(zip(orderedIDs, screenshots), uniquingKeysWith: { first, _ in first })
        forgetScreenshotsThatAreGone()
        adoptKeptAlbum()
        readCount = orderedIDs.filter { cards[$0]?.isRead == true }.count
        startReading()
    }

    /// Drops what we remember about screenshots that no longer exist.
    /// Skipped when the library looks empty or only partly shared, so a hiccup can never wipe your notes.
    private func forgetScreenshotsThatAreGone() {
        guard access == .authorized, !screenshots.isEmpty else { return }
        let gone = cards.keys.filter { assetsByID[$0] == nil }
        if !gone.isEmpty {
            var remaining = cards
            for id in gone {
                remaining[id] = nil
                searchTextByID[id] = nil
            }
            cards = remaining
            scheduleSave()
        }
        let stillMarked = markedForDelete.filter { assetsByID[$0] != nil }
        if stillMarked.count != markedForDelete.count { markedForDelete = stillMarked }
    }

    /// The "Finders Keepers" album in Photos is the lasting record of what was kept.
    /// If this app's own file is ever lost (a new phone, a reinstall), anything in the album counts as kept again.
    /// It also means adding a screenshot to that album in Photos keeps it here.
    private func adoptKeptAlbum() {
        guard access == .authorized else { return }
        let now = Date()
        for id in PhotoLibrary.keptAlbumIDs() {
            let isUndecidedHere = assetsByID[id] != nil && cards[id]?.keptAt == nil
            if isUndecidedHere, !takenOutOfAlbum.contains(id), !markedForDelete.contains(id) {
                update(id) { $0.keptAt = now }
            }
        }
    }

    func asset(_ id: String) -> PHAsset? {
        assetsByID[id]
    }

    func card(_ id: String) -> Card {
        cards[id] ?? Card(id: id)
    }

    /// The one place a card is changed, so search and saving always stay in step.
    private func update(_ id: String, _ change: (inout Card) -> Void) {
        var card = cards[id] ?? Card(id: id)
        change(&card)
        cards[id] = card
        searchTextByID[id] = nil
        scheduleSave()
    }

    // MARK: - Reading screenshots

    private enum Job {
        case read(PHAsset)
        case title(String)
    }

    /// Works through the backlog while the app is open, in two passes.
    /// First every screenshot's words are read, which is quick and makes search work.
    /// Then the on-device model writes a title for each, which is slower.
    private func startReading() {
        guard readTask == nil, hasAccess, nextJob() != nil else { return }
        isReading = true
        readTask = Task { [weak self] in await self?.workUntilDone() }
    }

    private func workUntilDone() async {
        while let job = nextJob() {
            switch job {
            case .read(let asset): await read(asset)
            case .title(let id): await writeTitle(for: id)
            }
        }
        isReading = false
        readTask = nil
        saveNow()
    }

    private func nextJob() -> Job? {
        if let asset = firstNeeding({ cards[$0]?.isRead != true && !couldNotRead.contains($0) }).flatMap({ assetsByID[$0] }) {
            return .read(asset)
        }
        guard OnDeviceModel.isAvailable else { return nil }
        return firstNeeding { cards[$0]?.isRead == true && cards[$0]?.isTitled == false && !couldNotTitle.contains($0) }
            .map(Job.title)
    }

    /// This week's batch comes first, then the newest, since recent screenshots are the ones you search for.
    private func firstNeeding(_ needsWork: (String) -> Bool) -> String? {
        func isCandidate(_ id: String) -> Bool { !markedForDelete.contains(id) && needsWork(id) }
        return lookQueueIDs().first(where: isCandidate) ?? orderedIDs.last(where: isCandidate)
    }

    private func read(_ asset: PHAsset) async {
        let id = asset.localIdentifier
        guard let reading = await ScreenshotReader.read(asset) else {
            couldNotRead.insert(id)      // skip for now, try again next launch
            return
        }
        let wasRead = cards[id]?.isRead == true
        update(id) { card in
            if !card.isEdited {
                card.title = reading.title
                card.group = reading.group
            }
            card.text = reading.text
            card.address = reading.facts.address
            card.links = reading.facts.links
            card.dates = reading.facts.dates
            card.isRead = true
            card.isTitled = reading.text.count < OnDeviceModel.minimumCharacters
        }
        if !wasRead, assetsByID[id] != nil { readCount += 1 }
    }

    private func writeTitle(for id: String) async {
        guard let text = cards[id]?.text, let filing = await OnDeviceModel.file(text) else {
            couldNotTitle.insert(id)     // skip for now, try again next launch
            return
        }
        update(id) { card in
            if !card.isEdited {
                card.title = filing.title
                card.group = filing.group
            }
            card.summary = filing.summary
            card.isTitled = true
        }
    }

    /// A line for the Pile describing the work in progress, or nil when there is none.
    var readingStatus: String? {
        guard isReading else { return nil }
        let total = orderedIDs.count
        if readCount < total {
            return "Reading \(readCount) of \(total). Search fills in as it goes."
        }
        return "Writing titles. \(titledCount) of \(total) done."
    }

    var titledCount: Int {
        orderedIDs.filter { cards[$0]?.isTitled == true }.count
    }

    func readEverythingAgain() {
        cards = cards.mapValues { card in
            var unread = card
            unread.isRead = false
            unread.isTitled = false
            return unread
        }
        couldNotRead = []
        couldNotTitle = []
        readCount = 0
        scheduleSave()
        startReading()
    }

    // MARK: - The weekly look

    private func lookQueueIDs(now: Date = Date()) -> [String] {
        settings.rules.batch(in: orderedIDs, cards: cards, excluding: markedForDelete, now: now)
    }

    /// This week's batch: the oldest screenshots that are due.
    func lookQueue() -> [PHAsset] {
        lookQueueIDs().compactMap { assetsByID[$0] }
    }

    /// Everything waiting in line, not just this week's batch.
    var dueCount: Int {
        settings.rules.dueIDs(in: orderedIDs, cards: cards, excluding: markedForDelete, now: Date()).count
    }

    @discardableResult
    func decide(_ verdict: Verdict, on asset: PHAsset, now: Date = Date()) -> UndoStep {
        let id = asset.localIdentifier
        let before = cards[id]
        let step = UndoStep(
            id: id,
            cardBefore: before,
            wasMarkedForDelete: markedForDelete.contains(id),
            addedToAlbum: verdict == .keep && before?.keptAt == nil
        )
        switch verdict {
        case .keep:
            if step.wasMarkedForDelete { markedForDelete.remove(id) }
            update(id) { card in
                card.keptAt = now
                card.snoozedAt = nil
            }
            takenOutOfAlbum.remove(id)
            if step.addedToAlbum { changeAlbum { await PhotoLibrary.setKept(true, asset) } }
        case .later:
            update(id) { card in
                card.snoozedAt = now
                card.snoozeCount += 1
            }
        case .delete:
            markedForDelete.insert(id)
            scheduleSave()
        }
        return step
    }

    func undo(_ step: UndoStep) {
        cards[step.id] = step.cardBefore
        searchTextByID[step.id] = nil
        if step.wasMarkedForDelete {
            markedForDelete.insert(step.id)
        } else {
            markedForDelete.remove(step.id)
        }
        if step.addedToAlbum, let asset = assetsByID[step.id] {
            takenOutOfAlbum.insert(step.id)
            changeAlbum { await PhotoLibrary.setKept(false, asset) }
        }
        scheduleSave()
        startReading()
    }

    /// Records that a look happened. Only a look carried through to the end counts toward the tally.
    func finishLook(completed: Bool) {
        lastLookAt = Date()
        if completed { looksCompleted += 1 }
        scheduleSave()
    }

    func unmarkAll() {
        markedForDelete = []
        scheduleSave()
    }

    /// Sends everything marked to Recently Deleted. iOS asks once for the whole batch.
    /// Returns false if the person cancels, in which case nothing changes.
    func deleteMarked() async -> Bool {
        let doomed = screenshots.filter { markedForDelete.contains($0.localIdentifier) }
        guard !doomed.isEmpty else {
            unmarkAll()
            return true
        }
        guard await PhotoLibrary.delete(doomed) else { return false }
        for asset in doomed {
            cards[asset.localIdentifier] = nil
            searchTextByID[asset.localIdentifier] = nil
        }
        markedForDelete = []
        reload()
        scheduleSave()
        return true
    }

    /// Album changes run one after another, so a quick keep-then-undo can never land out of order.
    private func changeAlbum(_ work: @escaping () async -> Void) {
        let earlier = albumWork
        albumWork = Task {
            await earlier?.value
            await work()
        }
    }

    // MARK: - The pile

    /// Newest first, narrowed by the search words and the chosen group.
    func pile(matching query: String, in group: String?) -> [PHAsset] {
        let tokens = TextRules.tokens(query)
        return screenshots.reversed().filter { asset in
            let id = asset.localIdentifier
            if markedForDelete.contains(id) { return false }
            if let group, cards[id]?.group != group { return false }
            return tokens.isEmpty || TextRules.matches(searchText(for: id), tokens)
        }
    }

    private func searchText(for id: String) -> String {
        if let cached = searchTextByID[id] { return cached }
        let text = cards[id]?.searchText ?? ""
        searchTextByID[id] = text
        return text
    }

    /// Screenshots that mention a day in the next six weeks, soonest first.
    func upcoming(now: Date = Date()) -> [Upcoming] {
        let from = now.addingTimeInterval(-12 * 3_600)
        let until = now.addingTimeInterval(42 * 86_400)
        return cards.values
            .filter { !markedForDelete.contains($0.id) && assetsByID[$0.id] != nil }
            .compactMap { card in
                card.dates.first { $0 > from && $0 < until }.map { Upcoming(card: card, date: $0) }
            }
            .sorted { $0.date < $1.date }
    }

    /// The few cards most likely to answer a question.
    func cardsRelevant(to question: String, limit: Int = 6) -> [Card] {
        var searchable: [String: String] = [:]
        for id in orderedIDs where !markedForDelete.contains(id) && cards[id]?.isRead == true {
            searchable[id] = searchText(for: id)
        }
        return TextRules.rank(question: question, searchTextByID: searchable, limit: limit).compactMap { cards[$0] }
    }

    /// A two-way link between a text field and one field of a card.
    func binding(_ id: String, _ field: WritableKeyPath<Card, String>, marksEdited: Bool = false) -> Binding<String> {
        Binding(
            get: { self.cards[id]?[keyPath: field] ?? Card(id: id)[keyPath: field] },
            set: { newValue in
                guard newValue != self.card(id)[keyPath: field] else { return }
                self.update(id) { card in
                    card[keyPath: field] = newValue
                    if marksEdited { card.isEdited = true }
                }
            }
        )
    }

    // MARK: - Reminder

    private func settingsChanged(from old: Settings) {
        scheduleSave()
        let reminderChanged = old.reminderOn != settings.reminderOn
            || old.reminderWeekday != settings.reminderWeekday
            || old.reminderHour != settings.reminderHour
            || old.reminderMinute != settings.reminderMinute
        if reminderChanged {
            Task { await applyReminder() }
        }
    }

    private func applyReminder() async {
        guard settings.reminderOn else {
            WeeklyReminder.cancel()
            remindersBlocked = false
            return
        }
        let scheduled = await WeeklyReminder.schedule(
            weekday: settings.reminderWeekday,
            hour: settings.reminderHour,
            minute: settings.reminderMinute
        )
        remindersBlocked = !scheduled
    }

    // MARK: - Saving

    private var snapshot: SavedState {
        var state = SavedState()
        state.cards = Array(cards.values)
        state.markedForDelete = Array(markedForDelete)
        state.lastLookAt = lastLookAt
        state.looksCompleted = looksCompleted
        state.settings = settings
        return state
    }

    /// Waits a moment so a burst of changes becomes one write.
    /// While a backlog is being read the wait is longer, to spare the phone's storage.
    private func scheduleSave() {
        guard saveTask == nil else { return }
        let wait: Duration = isReading ? .seconds(20) : .seconds(2)
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard let self, !Task.isCancelled else { return }
            self.saveTask = nil
            self.file.save(self.snapshot)
        }
    }

    /// Writes immediately. Called as the app goes to the background.
    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        file.saveNow(snapshot)
    }
}
