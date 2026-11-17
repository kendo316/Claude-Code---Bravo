import Photos
import SwiftUI

/// The weekly look: one screenshot at a time. Swipe it or use the buttons.
struct ReviewView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenSwipeHint") private var hasSeenSwipeHint = false

    /// Fixed when the look opens, so the line does not shift under your thumb.
    @State private var queue: [PHAsset]
    @State private var index = 0
    @State private var history: [Entry] = []
    @State private var drag: CGSize = .zero
    @State private var armed: Verdict?
    @State private var isFlinging = false
    @State private var didFinish = false
    @State private var zoomed: ScreenshotID?
    @State private var isDeleting = false
    @State private var deleteWasCancelled = false

    private struct Entry {
        let verdict: Verdict
        let step: UndoStep
    }

    init(queue: [PHAsset]) {
        _queue = State(initialValue: queue)
    }

    private var isDeciding: Bool { index < queue.count }

    var body: some View {
        ZStack {
            Color.wall.ignoresSafeArea()
            VStack(spacing: 12) {
                topBar
                if isDeciding {
                    cardStack
                    caption(for: queue[index])
                    if !hasSeenSwipeHint { swipeHint }
                    buttons
                } else {
                    summary
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .fullScreenCover(item: $zoomed) { item in
            if let asset = store.asset(item.id) {
                ZoomViewer(asset: asset)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                close()
            } label: {
                Image(systemName: "xmark").font(.headline).padding(8)
            }
            .accessibilityLabel("Close")
            Spacer()
            Text(isDeciding ? "\(index + 1) of \(queue.count)" : "Done")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.gold)
                .contentTransition(.numericText())
            Spacer()
            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward").font(.headline).padding(8)
            }
            .disabled(history.isEmpty || isFlinging)
            .accessibilityLabel("Undo")
        }
    }

    // MARK: - The card

    /// The current screenshot with the next one waiting behind it.
    private var cardStack: some View {
        ZStack {
            ForEach(queue[index..<min(index + 2, queue.count)], id: \.localIdentifier) { asset in
                let isFront = asset.localIdentifier == queue[index].localIdentifier
                Screenshot(asset: asset)
                    .overlay { if isFront { stamp } }
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
                    .scaleEffect(isFront ? 1 : 0.94)
                    .opacity(isFront ? 1 : 0.5)
                    .offset(isFront ? drag : .zero)
                    .rotationEffect(.degrees(isFront ? Double(drag.width) / 22 : 0))
                    .zIndex(isFront ? 1 : 0)
                    .allowsHitTesting(isFront && !isFlinging)
                    .onTapGesture { zoomed = ScreenshotID(id: asset.localIdentifier) }
                    .gesture(swipe)
                    .accessibilityHidden(!isFront)
                    .accessibilityLabel("Screenshot. Tap to zoom. Use the buttons below to decide.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The word that appears on the card once you have dragged far enough to commit.
    @ViewBuilder
    private var stamp: some View {
        if let armed {
            Text(armed.stamp)
                .font(.poster(40))
                .foregroundStyle(armed.color)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.ink.opacity(0.8), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(armed.color, lineWidth: 4))
                .rotationEffect(.degrees(-10))
                .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    private func caption(for asset: PHAsset) -> some View {
        let card = store.card(asset.localIdentifier)
        let details = [
            asset.creationDate.map { "\($0.shortDay) · \($0.ago)" },
            card.isRead ? CardGroup.named(card.group).name : nil,
            SignOff.snoozeNote(count: card.snoozeCount),
        ].compactMap { $0 }
        return VStack(alignment: .leading, spacing: 3) {
            Text(card.isRead ? card.displayTitle : "Reading…")
                .font(.headline)
                .lineLimit(2)
            Text(details.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(Color.quiet)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var swipeHint: some View {
        Text("Swipe right to keep, left to delete, up for next week. Or use the buttons.")
            .font(.caption)
            .foregroundStyle(Color.quiet)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            ForEach([Verdict.delete, .later, .keep], id: \.self) { verdict in
                Button {
                    fling(verdict)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: verdict.icon).font(.title3)
                        Text(verdict.label).font(.footnote.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(verdict.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(verdict == .delete ? Color.white : Color.ink)
                }
                .buttonStyle(.plain)
                .disabled(isFlinging)
            }
        }
    }

    // MARK: - Deciding

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isFlinging else { return }
                drag = value.translation
                let reached = verdict(for: value.translation)
                if reached != armed {
                    withAnimation(.spring(duration: 0.2)) { armed = reached }
                    if reached != nil { Haptics.tick() }
                }
            }
            .onEnded { value in
                guard !isFlinging else { return }
                if let verdict = verdict(for: value.translation) {
                    fling(verdict)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        drag = .zero
                        armed = nil
                    }
                }
            }
    }

    /// How far a drag has to go before letting go commits to an answer.
    private func verdict(for translation: CGSize) -> Verdict? {
        if translation.width > 110 { return .keep }
        if translation.width < -110 { return .delete }
        if translation.height < -130 { return .later }
        return nil
    }

    /// Sends the card off the screen, records the answer, and brings the next card forward.
    private func fling(_ verdict: Verdict) {
        guard isDeciding, !isFlinging else { return }
        let asset = queue[index]
        isFlinging = true
        hasSeenSwipeHint = true
        switch verdict {
        case .keep: Haptics.success()
        case .delete: Haptics.firm()
        case .later: Haptics.soft()
        }
        withAnimation(.easeIn(duration: 0.18)) {
            armed = verdict
            drag = verdict.exit
        }
        Task {
            try? await Task.sleep(for: .milliseconds(190))
            history.append(Entry(verdict: verdict, step: store.decide(verdict, on: asset)))
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                index += 1
                drag = .zero
                armed = nil
            }
            isFlinging = false
            if !isDeciding, !didFinish {
                didFinish = true
                store.finishLook(completed: true)
            }
        }
    }

    private func undo() {
        guard !isFlinging, let last = history.popLast() else { return }
        store.undo(last.step)
        Haptics.soft()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            index = max(0, index - 1)
            drag = .zero
            armed = nil
        }
    }

    private func close() {
        if !didFinish, !history.isEmpty {
            store.finishLook(completed: false)
        }
        dismiss()
    }

    // MARK: - Summary

    private func count(_ verdict: Verdict) -> Int {
        history.filter { $0.verdict == verdict }.count
    }

    private var summary: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("DONE")
                .font(.poster(80))
                .foregroundStyle(Color.gold)
            Text(SignOff.line(kept: count(.keep), deleted: count(.delete), later: count(.later)))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("\(count(.keep)) kept · \(count(.later)) next week · \(count(.delete)) to delete")
                .font(.subheadline)
                .foregroundStyle(Color.quiet)

            if !store.markedForDelete.isEmpty {
                Button(role: .destructive) {
                    deleteMarked()
                } label: {
                    Text(isDeleting ? "Deleting…" : "Delete \(store.markedForDelete.count) from Photos")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .disabled(isDeleting)
                .padding(.top, 10)
                Text(deleteWasCancelled
                     ? "Cancelled. They are still marked, and wait on the Weekly tab."
                     : "iOS asks you once for the lot. Recently Deleted keeps them for 30 days.")
                    .font(.footnote)
                    .foregroundStyle(Color.quiet)
                    .multilineTextAlignment(.center)
            }

            Button("Close") { close() }
                .padding(.top, 6)
            Spacer()
            if store.looksCompleted > 0 {
                Text("Look no. \(store.looksCompleted)")
                    .font(.caption)
                    .foregroundStyle(Color.quiet)
            }
        }
        .padding(.horizontal, 12)
    }

    private func deleteMarked() {
        isDeleting = true
        Task {
            let deleted = await store.deleteMarked()
            isDeleting = false
            if deleted {
                Haptics.success()
                dismiss()
            } else {
                deleteWasCancelled = true
            }
        }
    }
}

/// How each answer looks and behaves in the look.
private extension Verdict {
    var label: String {
        switch self {
        case .keep: "Keep"
        case .delete: "Delete"
        case .later: "Next week"
        }
    }

    var stamp: String {
        switch self {
        case .keep: "KEEP"
        case .delete: "DELETE"
        case .later: "NEXT WEEK"
        }
    }

    var icon: String {
        switch self {
        case .keep: "checkmark"
        case .delete: "trash"
        case .later: "clock.arrow.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .keep: .gold
        case .delete: Color(red: 0.84, green: 0.22, blue: 0.20)
        case .later: .paper
        }
    }

    /// Where the card flies to: right for keep, left for delete, up for next week.
    var exit: CGSize {
        switch self {
        case .keep: CGSize(width: 700, height: 40)
        case .delete: CGSize(width: -700, height: 40)
        case .later: CGSize(width: 0, height: -1_100)
        }
    }
}
