import SwiftUI
import UIKit

// The app uses Apple's own colors and type, so it follows Light and Dark mode and the
// text size set in Settings. The one accent color lives in Assets.xcassets (AccentColor).

/// The three answers in the weekly look, and how each one looks.
extension Verdict {
    var color: Color {
        switch self {
        case .keep: .green
        case .delete: .red
        case .later: .gray
        }
    }
}

/// Small taps you feel. Each choice in the weekly look has its own.
@MainActor
enum Haptics {
    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func firm() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

extension Date {
    /// "Mar 3, 2023"
    var shortDay: String { formatted(date: .abbreviated, time: .omitted) }

    /// "3 yr. ago"
    var ago: String { formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)) }
}

extension Settings {
    /// "Sunday at 7:00 PM"
    var reminderDescription: String {
        let days = Calendar.current.weekdaySymbols
        let day = days.indices.contains(reminderWeekday - 1) ? days[reminderWeekday - 1] : "Sunday"
        let time = Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? Date()
        return "\(day) at \(time.formatted(date: .omitted, time: .shortened))"
    }
}

extension Card {
    var displayTitle: String { title.isEmpty ? "Untitled screenshot" : title }

    /// The one fact most likely to tell you what this screenshot is, after its title.
    var keyFact: String? {
        if !address.isEmpty { return address }
        if let date = dates.first { return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()) }
        if !summary.isEmpty { return summary }
        return nil
    }
}
