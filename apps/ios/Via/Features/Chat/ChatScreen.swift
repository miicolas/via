import SwiftUI

struct ChatScreen: View {
    let model: ChatFeatureModel
    let onOpenItinerary: (ChatItinerary) -> Void

    @State private var draft = ""

    init(model: ChatFeatureModel, onOpenItinerary: @escaping (ChatItinerary) -> Void = { _ in }) {
        self.model = model
        self.onOpenItinerary = onOpenItinerary
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if model.messages.isEmpty {
                            ChatEmptyStateView(onPrompt: { prompt in
                                model.send(prompt)
                            })
                        }

                        ForEach(model.messages) { message in
                            ChatMessageRowView(message: message)
                                .id(message.id)
                        }

                        if let itinerary = model.latestItinerary {
                            ChatItineraryCardView(
                                itinerary: itinerary,
                                onOpen: { onOpenItinerary(itinerary) }
                            )
                        }

                        if model.isStreaming {
                            ProgressView("Via réfléchit…")
                                .font(.caption)
                                .foregroundStyle(ViaTheme.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let errorMessage = model.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(ViaTheme.critical)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.messages.count) { _, _ in
                    if let lastID = model.messages.last?.id {
                        withAnimation(.snappy) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    ChatComposerView(
                        text: $draft,
                        isDisabled: model.isStreaming,
                        onSend: {
                            model.send(draft)
                            draft = ""
                        },
                        onCancel: model.cancel
                    )
                }
            }
            .background(ViaTheme.ground)
            .navigationTitle("Via")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onDisappear {
            model.cancel()
        }
    }
}
