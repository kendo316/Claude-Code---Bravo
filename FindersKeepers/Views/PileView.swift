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

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3)

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
            #if DEBUG
            .task {
                if let search = DebugLaunch.searchText { query = search }
                guard DebugLaunch.opensNewest else { return }
                try? await Task.sleep(for: .seconds(2))
                opened = store.screenshots.last.map { ScreenshotID(id: $0.localIdentifier) }
            }
            #endif
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var statusLines: some View {
        if let status = store.readingStatus {
            HStack(spacing: 8) {
                ProgressView()
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
                                .foregroundStyle(.primary)
                                .frame(width: 140, alignment: .leading)
                                .padding(10)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.horizontal, 32)
                .multilineTextAlignment(.center)
        } else {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(shown, id: \.localIdentifier) { asset in
                    Button {
                        opened = ScreenshotID(id: asset.localIdentifier)
                    } label: {
                        Thumbnail(asset: asset, caption: caption(for: asset))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(store.card(asset.localIdentifier).displayTitle)
                    .contextMenu { quickActions(for: asset) }
                }
            }
            .padding(.horizontal)
        }
    }

    /// The title under a tile. Blank until the screenshot has been read, so nothing flickers.
    private func caption(for asset: PHAsset) -> String {
        let card = store.card(asset.localIdentifier)
        return card.isRead ? card.displayTitle : " "
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
