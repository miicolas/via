import SwiftUI

struct LineDetailView: View {
    @State private var viewModel: LineDetailViewModel
    private let route: RouteBadge

    init(viewModel: LineDetailViewModel, route: RouteBadge) {
        _viewModel = State(initialValue: viewModel)
        self.route = route
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                headerSection

                if let detail = viewModel.detail.value {
                    if viewModel.selectedDirection != nil {
                        LineServiceMapCard(
                            directions: detail.schemaDirections,
                            selectedDirectionID: directionSelection,
                            rows: viewModel.schemaRows,
                            lineColor: Color(transitHex: route.colorHex, fallback: .secondary),
                            activeDisruptions: detail.activeDisruptions,
                            onToggleRun: { viewModel.toggleRun($0) }
                        )
                    }

                    if !detail.activeDisruptions.isEmpty {
                        LineDisruptionsSection(
                            title: "Travaux en cours",
                            disruptions: detail.activeDisruptions
                        )
                    }

                    if !detail.upcomingDisruptions.isEmpty {
                        LineDisruptionsSection(
                            title: "Travaux à venir",
                            disruptions: detail.upcomingDisruptions
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.runAutomaticRefresh() }
        .navigationTitle("\(route.mode.displayName) \(route.shortName)")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if case .loading(nil) = viewModel.detail {
                SkeletonGate(isLoading: true) {
                    SkeletonList(
                        count: 10,
                        label: "Chargement de la ligne…",
                        row: .schemaStop
                    )
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .background(.background)
            } else if case .failed(_, nil) = viewModel.detail {
                EmptyStateView(
                    .offline(
                        title: "Ligne indisponible",
                        message: "Impossible de charger cette ligne. Réessayez.",
                    ),
                ) {
                    RetryButton { Task { await viewModel.refresh() } }
                        .primaryAction()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            }
        }
    }

    private var headerSection: some View {
        LineDetailHeaderView(
            route: route,
            condition: viewModel.detail.value?.condition ?? .normal,
            source: viewModel.detail.value?.source ?? .unavailable,
            fetchedAt: viewModel.detail.value?.fetchedAt
        )
    }

    private var directionSelection: Binding<String> {
        Binding(
            get: { viewModel.selectedDirection?.id ?? "" },
            set: { viewModel.selectedDirectionID = $0 }
        )
    }
}

#Preview("Métro 1 — travaux actifs") {
    NavigationStack {
        LineDetailView(
            viewModel: LineDetailViewModel(
                repository: PreviewLineStatusRepository(),
                lineID: PreviewLineStatusRepository.metro1.id
            ),
            route: PreviewLineStatusRepository.metro1
        )
    }
}

#Preview("RER A — branches et tronçons") {
    NavigationStack {
        LineDetailView(
            viewModel: LineDetailViewModel(
                repository: PreviewLineStatusRepository(),
                lineID: PreviewLineStatusRepository.rerA.id
            ),
            route: PreviewLineStatusRepository.rerA
        )
    }
}

#Preview("Sombre") {
    NavigationStack {
        LineDetailView(
            viewModel: LineDetailViewModel(
                repository: PreviewLineStatusRepository(),
                lineID: PreviewLineStatusRepository.metro1.id
            ),
            route: PreviewLineStatusRepository.metro1
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Dynamic Type — accessibilité 2") {
    NavigationStack {
        LineDetailView(
            viewModel: LineDetailViewModel(
                repository: PreviewLineStatusRepository(),
                lineID: PreviewLineStatusRepository.metro1.id
            ),
            route: PreviewLineStatusRepository.metro1
        )
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Service normal — écran complet") {
    let detail = PreviewLineStatusRepository.metro1Detail
    let normalDetail = LineDetail(
        route: detail.route,
        branches: detail.branches,
        directions: detail.directions,
        source: detail.source,
        fetchedAt: detail.fetchedAt,
        disruptions: []
    )
    let repository = PreviewLineStatusRepository(
        details: [detail.route.id: normalDetail]
    )

    NavigationStack {
        LineDetailView(
            viewModel: LineDetailViewModel(
                repository: repository,
                lineID: detail.route.id
            ),
            route: detail.route
        )
    }
}

#Preview("Travaux à venir — écran complet") {
    let detail = PreviewLineStatusRepository.metro1Detail
    let upcomingDetail = LineDetail(
        route: detail.route,
        branches: detail.branches,
        directions: detail.directions,
        source: detail.source,
        fetchedAt: detail.fetchedAt,
        disruptions: detail.disruptions.filter { !$0.isActive }
    )
    let repository = PreviewLineStatusRepository(
        details: [detail.route.id: upcomingDetail]
    )

    NavigationStack {
        LineDetailView(
            viewModel: LineDetailViewModel(
                repository: repository,
                lineID: detail.route.id
            ),
            route: detail.route
        )
    }
}
