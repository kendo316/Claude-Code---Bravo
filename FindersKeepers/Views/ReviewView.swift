import Photos
import SwiftUI

/// The weekly look: one screenshot at a time, shown at its real size.
/// Swipe right to keep, left to delete, up for next week, or use the buttons.
/// Tap the screenshot to hide the controls; double-tap or pinch to zoom.
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
    @State private var showsControls = true
    @State private var didFinish = false
    @State private var zoomed: ScreenshotID?
    @State private var isDeleting = false
    @State private var deleteWasCancelled = false

    /// How many screenshots ahead are fetched at full quality.
    private static let lookahead = 3

    private struct Entry {
        let verdict: Verdict
        let step: UndoStep
    }

    init(queue: [PHAsset]) {
        _queue = State(initialValue: queue)
    }

    private var isDeciding: Bool { index < queue.count }

    var body: some View {
        Group {
            if isDeciding {
                deciding
            } else {
                summary
            }
        }
        .statusBarHidden()
        .onAppear { prepareAhead() }
        .onChange(of: index) { prepareAhead() }
        .fullScreenCover(item: $zoomed) { item in
            if let asset = store.asset(item.id) {
                ZoomViewer(asset: asset)
            }
        }
    }

    // MARK: - Deciding

    private var deciding: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            stack
            VStack(spacing: 0) {
                if showsControls {
                    topBar.transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer(minLength: 0)
                if showsControls {
                    bottomPanel(for: queue[index]).transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsControls)
    }

    /// The current screenshot, with the next one already loaded underneath it.
    private var stack: some View {
        ZStack {
            ForEach(queue[index..<min(index + 2, queue.count)], id: \.localIdentifier) { asset in
                let isFront = asset.localIdentifier == queue[index].localIdentifier
                page(for: asset)
                    .overlay { if isFront { stamp } }
                    .offset(isFront ? drag : .zero)
                    .rotationEffect(.degrees(isFront ? Double(drag.width) / 40 : 0), anchor: .bottom)
                    .zIndex(isFront ? 1 : 0)
                    .allowsHitTesting(isFront && !isFlinging)
                    .accessibilityHidden(!isFront)
            }
        }
    }

    /// One screenshot, as wide as the screen, so it reads exactly as it did when you took it.
    private func page(for asset: PHAsset) -> some View {
        ZStack {
            Color(.systemBackground)
            Screenshot(asset: asset, cornerRadius: 0)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { zoomed = ScreenshotID(id: asset.localIdentifier) }
        .onTapGesture { showsControls.toggle() }
        .gesture(swipe)
        .simultaneousGesture(
            MagnifyGesture().onEnded { value in
                if value.magnification > 1.15 { zoomed = ScreenshotID(id: asset.localIdentifier) }
            }
        )
        .accessibilityElement()
        .accessibilityLabel(store.card(asset.localIdentifier).displayTitle)
        .accessibilityHint("Double-tap to zoom.")
        .accessibilityAction(named: "Keep") { fling(.keep) }
        .accessibilityAction(named: "Delete") { fling(.delete) }
        .accessibilityAction(named: "Next week") { fling(.later) }
    }

    /// The word that appears on the screenshot once a drag is far enough to count.
    @ViewBuilder
    private var stamp: some View {
        if let armed {
            Label(armed.label, systemImage: armed.icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(armed.color, in: Capsule())
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")
            Spacer()
            Text("\(index + 1) of \(queue.count)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
            Spacer()
            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(history.isEmpty || isFlinging)
            .accessibilityLabel("Undo")
        }
        .font(.headline)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    /// What the screenshot is, in large type, then the three choices.
    private func bottomPanel(for asset: PHAsset) -> some View {
        let card = store.card(asset.localIdentifier)
        let details = [
            asset.creationDate.map { "\($0.shortDay) · \($0.ago)" },
            card.isRead ? CardGroup.named(card.group).name : nil,
            SignOff.snoozeNote(count: card.snoozeCount),
        ].compactMap { $0 }

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(card.isRead ? card.displayTitle : "Reading…")
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                if card.isRead, let fact = card.keyFact {
                    Text(fact)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                Text(details.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !hasSeenSwipeHint {
                Text("Swipe right to keep, left to delete, up for next week. Tap the screenshot to see all of it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach([Verdict.delete, .later, .keep], id: \.self) { verdict in
                    Button {
                        fling(verdict)
                    } label: {
                        Label(verdict.label, systemImage: verdict.icon)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(verdict.color)
                    .controlSize(.large)
                    .disabled(isFlinging)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.bar)
    }

    // MARK: - Gestures and decisions

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 14)
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
        if translation.height < -140, abs(translation.width) < 90 { return .later }
        return nil
    }

    /// Sends the screenshot off the screen, records the answer, and reveals the next one.
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
        withAnimation(.easeIn(duration: 0.2)) {
            armed = verdict
            drag = verdict.exit
        }
        Task {
            try? await Task.sleep(for: .milliseconds(210))
            history.append(Entry(verdict: verdict, step: store.decide(verdict, on: asset)))
            var instantly = Transaction()
            instantly.disablesAnimations = true
            withTransaction(instantly) {
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
        let came = last.verdict.exit
        var instantly = Transaction()
        instantly.disablesAnimations = true
        withTransaction(instantly) {
            index = max(0, index - 1)
            drag = came
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            drag = .zero
        }
    }

    private func prepareAhead() {
        let upcoming = queue.dropFirst(index).prefix(Self.lookahead + 1)
        ImageLoader.prepare(upcoming)
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
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: didFinish)
            Text("Done")
                .font(.largeTitle.weight(.bold))
            Text(SignOff.line(kept: count(.keep), deleted: count(.delete), later: count(.later)))
                .font(.title3)
                .multilineTextAlignment(.center)
            Text("\(count(.keep)) kept · \(count(.later)) next week · \(count(.delete)) to delete")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Close") { close() }
                .padding(.top, 6)
            Spacer()
            if store.looksCompleted > 0 {
                Text("Look no. \(store.looksCompleted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 28)
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

/// How each answer reads and moves in the look.
private extension Verdict {
    var label: String {
        switch self {
        case .keep: "Keep"
        case .delete: "Delete"
        case .later: "Next week"
        }
    }

    var icon: String {
        switch self {
        case .keep: "checkmark"
        case .delete: "trash"
        case .later: "clock.arrow.circlepath"
        }
    }

    /// Where the screenshot flies to: right for keep, left for delete, up for next week.
    var exit: CGSize {
        switch self {
        case .keep: CGSize(width: 800, height: 60)
        case .delete: CGSize(width: -800, height: 60)
        case .later: CGSize(width: 0, height: -1_300)
        }
    }
}
