import Foundation

/// The choices on the More tab.
struct Settings: Codable, Equatable {
    var batchSize = 25
    var resurfaceAfterDays = 180
    /// Off until asked for, so the notification prompt appears only when you choose it.
    var reminderOn = false
    /// 1 is Sunday, 7 is Saturday.
    var reminderWeekday = 1
    var reminderHour = 19
    var reminderMinute = 0
    /// Stops the screen locking while a backlog is read. Meant for a phone left on its charger.
    var keepAwakeWhileReading = false

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        batchSize = values.value(.batchSize, or: 25)
        resurfaceAfterDays = values.value(.resurfaceAfterDays, or: 180)
        reminderOn = values.value(.reminderOn, or: false)
        reminderWeekday = values.value(.reminderWeekday, or: 1)
        reminderHour = values.value(.reminderHour, or: 19)
        reminderMinute = values.value(.reminderMinute, or: 0)
        keepAwakeWhileReading = values.value(.keepAwakeWhileReading, or: false)
    }

    var rules: ReviewRules {
        ReviewRules(batchSize: batchSize, resurfaceAfterDays: resurfaceAfterDays)
    }
}

/// Everything written to disk. One small file in the app's private storage.
struct SavedState: Codable, Equatable {
    static let currentVersion = 1

    var version = SavedState.currentVersion
    var cards: [Card] = []
    var markedForDelete: [String] = []
    var lastLookAt: Date?
    var looksCompleted = 0
    var settings = Settings()

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = values.value(.version, or: SavedState.currentVersion)
        cards = values.value(.cards, or: [])
        markedForDelete = values.value(.markedForDelete, or: [])
        lastLookAt = try? values.decodeIfPresent(Date.self, forKey: .lastLookAt)
        looksCompleted = values.value(.looksCompleted, or: 0)
        settings = values.value(.settings, or: Settings())
    }
}
