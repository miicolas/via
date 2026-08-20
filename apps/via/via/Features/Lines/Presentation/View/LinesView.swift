import SwiftUI

struct LinesView: View {
    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress

    let viewModel: LinesViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            List {
                if showsUnavailableBanner {
                    LinesUnavailableBanner()
                }

                ForEach(viewModel.sections, id: \.mode) { section in
                    Section(section.mode.displayName) {
                        ForEach(section.lines) { status in
                            NavigationLink(value: status) {
                                LineStatusRow(status: status)
                            }
                        }
                    }
                }

                if isSearching, !viewModel.extraSearchResults.isEmpty {
                    Section("Autres lignes") {
                        ForEach(viewModel.extraSearchResults) { status in
                            NavigationLink(value: status) {
                                LineStatusRow(status: status)
                            }
                        }
                    }
                }

                if !isSearching {
                    UpcomingClosuresSection(days: viewModel.upcomingByDay)
                }
            }
            .navigationTitle("Lignes")
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(text: $viewModel.searchText, prompt: "Ligne, mode, bus…")
            .navigationDestination(for: LineStatus.self) { status in
                LineDetailView(
                    viewModel: viewModel.detailViewModel(for: status.route),
                    route: status.route
                )
            }
            .overlay {
                if case .loading(nil) = viewModel.board {
                    SkeletonGate(isLoading: true) {
                        SkeletonList(
                            count: 8,
                            label: "Chargement des lignes…",
                            row: .lineStatus
                        )
                        .padding(.horizontal, 20)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(.background)
                } else if isSearching, viewModel.sections.isEmpty,
                          viewModel.extraSearchResults.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else if case .failed(_, nil) = viewModel.board {
                    ContentUnavailableView(
                        "Lignes indisponibles",
                        systemImage: "wifi.exclamationmark",
                        description: Text("Impossible de charger l’état du réseau. Réessayez.")
                    )
                }
            }
            .refreshable { await viewModel.refresh() }
        }
        .task { await viewModel.runAutomaticRefresh() }
        .task(id: viewModel.searchText) { await viewModel.search(query: viewModel.searchText) }
        .opacity(tabVisibilityProgress)
    }

    private var isSearching: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsUnavailableBanner: Bool {
        if viewModel.board.value?.source == .unavailable { return true }
        if case .failed(_, .some) = viewModel.board { return true }
        return false
    }
}

#Preview {
    let repository = PreviewLineStatusRepository()

    LinesView(
        viewModel: LinesViewModel(repository: repository)
    )
}
