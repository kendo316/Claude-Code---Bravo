import SwiftUI
import UIKit

extension Color {
    /// The deep blue behind everything.
    static let wall = Color(red: 0.075, green: 0.125, blue: 0.231)
    /// A slightly lighter blue for panels that sit on the wall.
    static let panel = Color(red: 0.118, green: 0.180, blue: 0.310)
    static let gold = Color(red: 0.965, green: 0.659, blue: 0.129)
    static let paper = Color(red: 0.949, green: 0.929, blue: 0.886)
    static let ink = Color(red: 0.047, green: 0.082, blue: 0.157)
    static let quiet = Color.white.opacity(0.62)
}

extension Font {
    /// Tall, tight capitals for the few big moments.
    static func poster(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.condensed)
    }
}

/// Small taps you feel. Each choice in the weekly look has its own.
@MainActor
enum Haptics {
    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func firm() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

extension Date {
    /// "Mar 3, 2023"
    var shortDay: String { formatted(date: .abbreviated, time: .omitted) }

    /// "3 yr. ago"
    var ago: String { formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)) }
}

extension Card {
    var displayTitle: String { title.isEmpty ? "Untitled screenshot" : title }
}
