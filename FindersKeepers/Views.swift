import SwiftUI
import Photos

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0

    var body: some View {
        Group {
            if store.canRead {
                TabView(selection: $tab) {
                    PileView().tabItem { Label("Pile", systemImage: "square.grid.3x3.fill") }.tag(0)
                    WeeklyView().tabItem { Label("Weekly", systemImage: "calendar.badge.clock") }.tag(1)
                    MoreView().tabItem { Label("More", systemImage: "ellipsis.circle") }.tag(2)
                }
                .tint(.gold)
            } else {
                AccessView()
            }
        }
        .background(Color.wall.ignoresSafeArea())
        .onAppear {
            if UserDefaults.standard.bool(forKey: "openWeekly") {
                UserDefaults.standard.set(false, forKey: "openWeekly")
                tab = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWeekly)) { _ in
            UserDefaults.standard.set(false, forKey: "openWeekly")
            tab = 1
        }
    }
}

struct AccessView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("FINDERS\nKEEPERS")
                .font(.system(size: 46, weight: .black))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.gold)
            Text("Needs your Photos so it can see your screenshots. They are read on this phone only. Nothing is uploaded.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 32)
            if store.auth == .notDetermined {
                Button("Allow access") { Task { await store.requestAccess() } }
                    .buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
            } else {
                Button("Open Settings") {
                    if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                }
                .buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
                Text("Photos access is off. Turn it on in Settings, then come back.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
    }
}

// MARK: - Thumbnail

struct Thumb: View {
    let asset: PHAsset
    @State private var img: UIImage?

    var body: some View {
        Color.black.opacity(0.25)
            .aspectRatio(0.5, contentMode: .fit)
            .overlay {
                if let img { Image(uiImage: img).resizable().scaledToFill() }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .task(id: asset.localIdentifier) {
                img = await PhotoLib.image(for: asset, size: CGSize(width: 330, height: 660), mode: .aspectFill)
            }
    }
}

struct DetailTarget: Identifiable { let id: String }

// MARK: - Pile

struct PileView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @State private var group: String?
    @State private var detail: DetailTarget?
    @State private var showAsk = false

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if store.reading || store.readDone < store.readTotal {
                        HStack(spacing: 8) {
                            ProgressView().tint(.gold)
                            Text("Reading \(store.readDone) of \(store.readTotal). Keep the app open.")
                                .font(.footnote).foregroundStyle(.white.opacity(0.7))
                        }.padding(.horizontal)
                    }
                    if store.auth == .limited {
                        Button("You shared only some photos. Add more.") {
                            if let vc = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.keyWindow?.rootViewController {
                                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: vc)
                            }
                        }.font(.footnote).padding(.horizontal)
                    }

                    let soon = store.upcoming()
                    if !soon.isEmpty && query.isEmpty && group == nil {
                        Text("COMING UP").font(.caption.bold()).foregroundStyle(Color.gold).padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(soon) { item in
                                    Button { detail = DetailTarget(id: item.card.id) } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.date.formatted(.dateTime.month(.abbreviated).day()))
                                                .font(.caption.bold()).foregroundStyle(.black)
                                            Text(item.card.title).font(.caption).lineLimit(2).foregroundStyle(.black)
                                        }
                                        .frame(width: 130, alignment: .leading)
                                        .padding(10).background(Color.paper).clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }.padding(.horizontal)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            chip("All", on: group == nil) { group = nil }
                            ForEach(Groups.all) { g in
                                chip(g.name, on: group == g.id) { group = (group == g.id) ? nil : g.id }
                            }
                        }.padding(.horizontal)
                    }

                    let shown = store.search(query, group: group)
                    LazyVGrid(columns: cols, spacing: 6) {
                        ForEach(shown, id: \.localIdentifier) { a in
                            Button { detail = DetailTarget(id: a.localIdentifier) } label: {
                                Thumb(asset: a)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 6)
                    if shown.isEmpty {
                        Text(query.isEmpty ? "No screenshots here yet." : "Nothing matches. Words inside screenshots count, once they've been read.")
                            .foregroundStyle(.white.opacity(0.6)).padding()
                    }
                }
            }
            .background(Color.wall)
            .navigationTitle("Pile")
            .searchable(text: $query, prompt: "Search titles and words inside")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAsk = true } label: { Image(systemName: "sparkles") }
                }
            }
            .sheet(item: $detail) { DetailView(id: $0.id) }
            .sheet(isPresented: $showAsk) { AskView() }
        }
    }

    private func chip(_ t: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.footnote.bold())
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(on ? Color.gold : Color.white.opacity(0.1))
                .foregroundStyle(on ? Color.black : Color.white)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Detail

struct DetailView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let id: String
    @State private var img: UIImage?
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let img {
                        Image(uiImage: img).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    TextField("Title", text: store.binding(id, \.title), axis: .vertical)
                        .font(.title2.bold())
                    Picker("Group", selection: store.binding(id, \.group)) {
                        ForEach(Groups.all) { Text($0.name).tag($0.id) }
                    }.tint(.gold)

                    if let c = store.cards[id] {
                        if !c.summary.isEmpty { Text(c.summary).foregroundStyle(.white.opacity(0.85)) }
                        ForEach(c.dates, id: \.self) { d in
                            Button {
                                Task {
                                    let ok = await Cal.add(title: c.title, date: d, notes: c.summary)
                                    toast = ok ? "Added to your calendar" : "Couldn't add it. Check Calendar access."
                                }
                            } label: {
                                Label(d.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar.badge.plus")
                            }
                        }
                        if !c.address.isEmpty {
                            Button {
                                let q = c.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                if let u = URL(string: "http://maps.apple.com/?q=\(q)") { UIApplication.shared.open(u) }
                            } label: { Label(c.address, systemImage: "mappin.and.ellipse") }
                        }
                        ForEach(c.links, id: \.self) { l in
                            if let u = URL(string: l) { Link(l, destination: u).font(.footnote).lineLimit(1) }
                        }
                        TextField("Note", text: store.binding(id, \.note), axis: .vertical)
                            .padding(10).background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8))
                        if !c.text.isEmpty {
                            Text("TEXT IN THIS SCREENSHOT").font(.caption.bold()).foregroundStyle(Color.gold)
                            Text(c.text).font(.footnote.monospaced()).textSelection(.enabled)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    } else {
                        Text("Not read yet. It will be soon.").foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding()
            }
            .background(Color.wall)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        if let a = store.asset(id) { _ = store.markDelete(a) }
                        dismiss()
                    } label: { Image(systemName: "trash") }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast).padding(12).background(Color.paper).foregroundStyle(.black)
                        .clipShape(Capsule()).padding(.bottom, 20)
                        .task { try? await Task.sleep(nanoseconds: 2_200_000_000); self.toast = nil }
                }
            }
            .task {
                if let a = store.asset(id) {
                    img = await PhotoLib.image(for: a, size: CGSize(width: 1200, height: 2400))
                }
            }
        }
    }
}

// MARK: - Ask your pile

struct AskView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var q = ""
    @State private var answer = ""
    @State private var busy = false
    @State private var used: [Card] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Ask your pile. Where was that taco place?", text: $q, axis: .vertical)
                        .padding(12).background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                    Button {
                        Task { await run() }
                    } label: {
                        Text(busy ? "Thinking…" : "Ask").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
                    .disabled(busy || q.trimmingCharacters(in: .whitespaces).isEmpty)

                    if !answer.isEmpty { Text(answer) }
                    if !used.isEmpty {
                        Text("FROM THESE").font(.caption.bold()).foregroundStyle(Color.gold)
                        ForEach(used) { c in
                            Text("• \(c.title)").font(.footnote).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }.padding()
            }
            .background(Color.wall)
            .navigationTitle("Ask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } } }
        }
    }

    private func run() async {
        busy = true; answer = ""
        let words = Set(q.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count > 2 })
        let scored = store.cards.values
            .filter { !store.pending.contains($0.id) }
            .map { c -> (Card, Int) in
                let h = c.haystack
                return (c, words.reduce(0) { $0 + (h.contains($1) ? 1 : 0) })
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(6)
            .map { $0.0 }
        used = Array(scored)
        answer = await Reader.ask(q, cards: used)
        busy = false
    }
}
