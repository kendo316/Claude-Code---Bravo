import Photos
import PhotosUI
import SwiftUI

/// Every screenshot, newest first, with search and groups.
struct PileView: View {
    @EnvironmentObject private var store: Store
    @State private var query = ""
    @State private var group: String?
    @State private var opened: ScreenshotID?
    @State private var isAsking = false
    @State private var toast: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    statusLines
                    if query.isEmpty, group == nil { comingUp }
                    groupChips
                    grid
                }
                .padding(.vertical, 8)
            }
            .background(Color.wall.ignoresSafeArea())
            .navigationTitle("Pile")
            .searchable(text: $query, prompt: "Search titles and the words inside")
            .refreshable { store.reload() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAsking = true
                    } label: {
                        Image(systemName: "sparkles")
                    }
                    .accessibilityLabel("Ask your pile")
                }
            }
            .sheet(item: $opened) { DetailView(id: $0.id) }
            .sheet(isPresented: $isAsking) { AskView() }
            .toast($toast)
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var statusLines: some View {
        if store.isReading {
            HStack(spacing: 8) {
                ProgressView().tint(Color.gold)
                Text("Reading \(store.readCount) of \(store.screenshots.count). Search fills in as it goes.")
                    .font(.footnote)
                    .foregroundStyle(Color.quiet)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal)
        }
        if store.access == .limited {
            Button("Only some photos are shared with the app. Share more.") {
                presentLimitedLibraryPicker()
            }
            .font(.footnote)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var comingUp: some View {
        let soon = store.upcoming()
        if !soon.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("COMING UP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.gold)
                    .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(soon) { item in
                            Button {
                                opened = ScreenshotID(id: item.card.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                        .font(.caption.weight(.bold))
                                    Text(item.card.displayTitle)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .foregroundStyle(Color.ink)
                                .frame(width: 140, alignment: .leading)
                                .padding(10)
                                .background(Color.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var groupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Chip(title: "All", isOn: group == nil) { group = nil }
                ForEach(CardGroup.all) { item in
                    Chip(title: item.name, isOn: group == item.id) {
                        group = (group == item.id) ? nil : item.id
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var grid: some View {
        let shown = store.pile(matching: query, in: group)
        if shown.isEmpty {
            Text(emptyMessage)
                .foregroundStyle(Color.quiet)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.horizontal, 32)
                .multilineTextAlignment(.center)
        } else {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(shown, id: \.localIdentifier) { asset in
                    Button {
                        opened = ScreenshotID(id: asset.localIdentifier)
                    } label: {
                        Thumbnail(asset: asset)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(store.card(asset.localIdentifier).displayTitle)
                    .contextMenu { quickActions(for: asset) }
                }
            }
            .padding(.horizontal, 6)
        }
    }

    private var emptyMessage: String {
        if store.screenshots.isEmpty { return "No screenshots yet. Take one and it shows up here." }
        if !query.isEmpty { return "Nothing matches “\(query)”. Words inside a screenshot count once it has been read." }
        return "Nothing filed here yet."
    }

    /// Press and hold a tile for these.
    @ViewBuilder
    private func quickActions(for asset: PHAsset) -> some View {
        let card = store.card(asset.localIdentifier)
        Button {
            store.decide(.keep, on: asset)
            Haptics.success()
            toast = "Kept"
        } label: {
            Label("Keep", systemImage: "checkmark")
        }
        if !card.text.isEmpty {
            Button {
                UIPasteboard.general.string = card.text
                toast = "Text copied"
            } label: {
                Label("Copy the text", systemImage: "doc.on.doc")
            }
        }
        Button(role: .destructive) {
            store.decide(.delete, on: asset)
            Haptics.firm()
            toast = "Marked. Finish on the Weekly tab."
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func presentLimitedLibraryPicker() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let root = scenes.first?.keyWindow?.rootViewController else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: root)
    }
}
