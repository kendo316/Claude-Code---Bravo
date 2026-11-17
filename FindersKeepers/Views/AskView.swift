import SwiftUI

/// Ask a plain question. The on-device model answers from the screenshots most likely to know.
struct AskView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var answer: String?
    @State private var sources: [Card] = []
    @State private var isThinking = false
    @State private var opened: ScreenshotID?
    @FocusState private var isTyping: Bool

    private var trimmed: String { question.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Where was that taco place?", text: $question, axis: .vertical)
                        .focused($isTyping)
                        .submitLabel(.search)
                        .onSubmit { ask() }
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button {
                        ask()
                    } label: {
                        Text(isThinking ? "Thinking…" : "Ask").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isThinking || trimmed.isEmpty)

                    if let answer {
                        Text(answer).textSelection(.enabled)
                    }
                    if !sources.isEmpty {
                        Text("FROM THESE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        ForEach(sources) { card in
                            Button {
                                opened = ScreenshotID(id: card.id)
                            } label: {
                                HStack(spacing: 10) {
                                    if let asset = store.asset(card.id) {
                                        Thumbnail(asset: asset).frame(width: 34)
                                    }
                                    Text(card.displayTitle)
                                        .font(.subheadline)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Ask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $opened) { DetailView(id: $0.id) }
            .onAppear { isTyping = true }
        }
    }

    private func ask() {
        guard !isThinking, !trimmed.isEmpty else { return }
        let asked = trimmed
        isThinking = true
        isTyping = false
        answer = nil
        sources = store.cardsRelevant(to: asked)
        Task {
            if sources.isEmpty {
                answer = "Nothing in your pile mentions that yet."
            } else if let reply = await OnDeviceModel.answer(asked, using: sources) {
                answer = reply
            } else {
                answer = "Apple Intelligence isn't answering right now. These are the closest matches."
            }
            isThinking = false
        }
    }
}
