import Foundation

/// The line shown when a weekly look ends. It changes with how the look went.
enum SignOff {
    static func line(kept: Int, deleted: Int, later: Int) -> String {
        let total = kept + deleted + later
        if total == 0 { return "Nothing decided. The pile will wait." }
        if later == total { return "Kicked the whole can down the road. Bold." }
        if deleted == total { return "Scorched earth. Respect." }
        if kept == total { return "Kept every one. Finders keepers, as advertised." }
        if later == 0 { return "Clean sweep. No maybes." }
        if deleted > kept { return "Lighter pile, clearer head." }
        return "Good look. Same time next week."
    }

    /// A nudge shown under a screenshot that keeps getting put off.
    static func snoozeNote(count: Int) -> String? {
        switch count {
        case ..<1: return nil
        case 1, 2: return "put off \(count)×"
        case 3, 4: return "put off \(count)×. Be honest."
        default: return "put off \(count)×. It lives here now."
        }
    }
}
