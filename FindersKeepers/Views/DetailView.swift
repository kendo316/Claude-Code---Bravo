import SwiftUI
import UIKit

/// One screenshot and everything found in it.
struct DetailView: View {
    let id: String
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var isZoomed = false
    @State private var eventDate: EventDate?
    @State private var toast: String?
    @State private var shareImage: UIImage?

    private struct EventDate: Identifiable {
        let date: Date
        var id: Date { date }
    }

    var body: some View {
        let card = store.card(id)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let asset = store.asset(id) {
                        Button {
                            isZoomed = true
                        } label: {
                            Screenshot(asset: asset)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Screenshot. Tap to zoom.")
                        .fullScreenCover(isPresented: $isZoomed) { ZoomViewer(asset: asset) }
                    }

                    TextField("Title", text: store.binding(id, \.title, marksEdited: true), axis: .vertical)
                        .font(.title2.weight(.bold))

                    HStack {
                        Picker("Group", selection: store.binding(id, \.group, marksEdited: true)) {
                            ForEach(CardGroup.all) { Text($0.name).tag($0.id) }
                        }
                        .labelsHidden()
                        Spacer()
                        if let taken = store.asset(id)?.creationDate {
                            Text("\(taken.shortDay) · \(taken.ago)")
                                .font(.footnote)
                                .foregroundStyle(Color.quiet)
                        }
                    }

                    if let keptAt = card.keptAt {
                        Label("Kept \(keptAt.shortDay)", systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.gold)
                    }

                    if !card.summary.isEmpty {
                        Text(card.summary).foregroundStyle(.white.opacity(0.88))
                    }

                    facts(for: card)

                    TextField("Add a note", text: store.binding(id, \.note), axis: .vertical)
                        .padding(12)
                        .background(Color.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if !card.text.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TEXT IN THIS SCREENSHOT")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.gold)
                            Text(card.text)
                                .font(.footnote.monospaced())
                                .foregroundStyle(Color.quiet)
                                .textSelection(.enabled)
                        }
                    } else if !card.isRead {
                        Text("Not read yet. It will be soon.")
                            .font(.footnote)
                            .foregroundStyle(Color.quiet)
                    }
                }
                .padding()
            }
            .background(Color.wall.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview(card.displayTitle, image: Image(uiImage: shareImage))
                        )
                    }
                    Menu {
                        actions(for: card)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More actions")
                }
            }
            .sheet(item: $eventDate) { item in
                EventEditor(title: card.displayTitle, date: item.date, notes: card.summary)
                    .ignoresSafeArea()
            }
            .toast($toast)
            .task {
                if let asset = store.asset(id) {
                    shareImage = await ImageLoader.screen(for: asset)
                }
            }
        }
    }

    /// Dates, the address and links, each one tap from being useful.
    @ViewBuilder
    private func facts(for card: Card) -> some View {
        if !card.dates.isEmpty || !card.address.isEmpty || !card.links.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(card.dates, id: \.self) { date in
                    Button {
                        eventDate = EventDate(date: date)
                    } label: {
                        Label(date.formatted(date: .complete, time: .shortened), systemImage: "calendar.badge.plus")
                            .multilineTextAlignment(.leading)
                    }
                }
                if !card.address.isEmpty {
                    Button {
                        openMaps(card.address)
                    } label: {
                        Label(card.address, systemImage: "mappin.and.ellipse")
                            .multilineTextAlignment(.leading)
                    }
                }
                ForEach(card.links, id: \.self) { link in
                    if let url = URL(string: link) {
                        Link(destination: url) {
                            Label(url.host() ?? link, systemImage: "link").lineLimit(1)
                        }
                    }
                }
            }
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private func actions(for card: Card) -> some View {
        if let asset = store.asset(id) {
            Button {
                store.decide(.keep, on: asset)
                Haptics.success()
                toast = "Kept"
            } label: {
                Label("Keep", systemImage: "checkmark")
            }
        }
        if !card.text.isEmpty {
            Button {
                UIPasteboard.general.string = card.text
                toast = "Text copied"
            } label: {
                Label("Copy the text", systemImage: "doc.on.doc")
            }
        }
        if let asset = store.asset(id) {
            Button(role: .destructive) {
                store.decide(.delete, on: asset)
                Haptics.firm()
                dismiss()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func openMaps(_ address: String) {
        var parts = URLComponents(string: "https://maps.apple.com/")
        parts?.queryItems = [URLQueryItem(name: "q", value: address)]
        if let url = parts?.url {
            UIApplication.shared.open(url)
        }
    }
}
