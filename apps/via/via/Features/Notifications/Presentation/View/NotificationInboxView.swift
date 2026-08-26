import SwiftUI

struct NotificationInboxView: View {
    let remote: any NotificationInboxRemote

    @Environment(\.openURL) private var openURL
    @State private var pageState: Loadable<NotificationInboxPage> = .idle

    init(remote: any NotificationInboxRemote = NoOpNotificationInboxRemote()) {
        self.remote = remote
    }

    var body: some View {
        List {
            if let page = pageState.value, !page.items.isEmpty {
                ForEach(page.items) { item in
                    Button {
                        open(item)
                    } label: {
                        NotificationInboxRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(item.readAt == nil ? Color.accentColor.opacity(0.06) : nil)
                }

                if page.nextCursor != nil {
                    Button("Charger plus", systemImage: "arrow.down.circle") {
                        Task { await loadNextPage() }
                    }
                    .primaryAction()
                    .listRowSeparator(.hidden)
                }
            } else if case .loaded = pageState {
                EmptyStateView(.emptyInbox) {
                    Button("Actualiser", systemImage: "arrow.clockwise") {
                        Task { await load() }
                    }
                    .secondaryAction()
                }
                .listRowSeparator(.hidden)
            }
        }
        .navigationTitle("Centre de notifications")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if case .loading(nil) = pageState {
                SkeletonGate(isLoading: true) {
                    SkeletonList(count: 6, label: "Chargement des notifications…", row: .lineStatus)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            } else if case .failed(_, nil) = pageState {
                EmptyStateView(
                    .offline(
                        title: "Notifications indisponibles",
                        message: "Impossible de charger votre historique. Réessayez.",
                    )
                ) {
                    Button("Réessayer", systemImage: "arrow.clockwise") {
                        Task { await load() }
                    }
                    .primaryAction()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            }
        }
        .hapticRefreshable { await load() }
        .task { await load() }
        .onDisappear {
            guard pageState.value?.unreadCount ?? 0 > 0 else { return }
            Task { try? await remote.markRead(before: .now) }
        }
    }

    private func load() async {
        pageState = .loading(previous: pageState.value)
        do {
            pageState = .loaded(try await remote.page(cursor: nil, limit: 50))
        } catch is CancellationError {
            return
        } catch {
            pageState = .failed(error.via, previous: pageState.value)
        }
    }

    private func loadNextPage() async {
        guard let page = pageState.value, let cursor = page.nextCursor else { return }
        do {
            let next = try await remote.page(cursor: cursor, limit: 50)
            pageState = .loaded(NotificationInboxPage(
                items: page.items + next.items,
                nextCursor: next.nextCursor,
                unreadCount: next.unreadCount
            ))
        } catch {
            // The already-loaded page remains useful. A pull-to-refresh retries.
        }
    }

    private func open(_ item: NotificationInboxItem) {
        guard let deepLink = item.deepLink, let url = URL(string: deepLink) else { return }
        openURL(url)
    }
}
