import Foundation

/// Reads and writes the app's one data file.
/// It lives in the app's private storage and is encrypted by iOS whenever the phone is locked.
final class CardFile {
    private let url: URL
    private let queue = DispatchQueue(label: "FindersKeepers.CardFile", qos: .utility)   // one write at a time, in order

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent("cards.json")
    }

    /// A missing file means a first launch. An unreadable one is set aside, never overwritten.
    func load() -> SavedState {
        guard let data = try? Data(contentsOf: url) else { return SavedState() }
        if let state = try? JSONDecoder().decode(SavedState.self, from: data) { return state }
        let rescue = url.deletingLastPathComponent().appendingPathComponent("cards-unreadable.json")
        try? FileManager.default.removeItem(at: rescue)
        try? FileManager.default.moveItem(at: url, to: rescue)
        return SavedState()
    }

    /// Saves in the background.
    func save(_ state: SavedState) {
        queue.async { self.write(state) }
    }

    /// Saves and waits. Used when the app is about to be suspended.
    func saveNow(_ state: SavedState) {
        queue.sync { self.write(state) }
    }

    private func write(_ state: SavedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}
