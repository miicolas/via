import SwiftUI

struct LineDetailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel: LineDetailViewModel
    private let route: RouteBadge

    init(viewModel: LineDetailViewModel, route: RouteBadge) {
        _viewModel = State(initialValue: viewModel)
        self.route = route
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                LineDetailHeaderView(
                    route: route,
                    condition: viewModel.detail.value?.condition ?? .normal,
                    source: viewModel.detail.value?.source ?? .unavailable,
                    fetchedAt: viewModel.detail.value?.fetchedAt
                )

                if let detail = viewModel.detail.value {
                    if !detail.disruptions.isEmpty {
                        LineDisruptionsSection(
                            active: detail.activeDisruptions,
                            upcoming: detail.upcomingDisruptions
                        )
                    }

                    LinePlanView(
                        strips: viewModel.strips,
                        lineColor: Color(transitHex: route.colorHex, fallback: .secondary),
                        isOpen: { viewModel.isOpen($0) },
                        onToggle: { strip in
                            withAnimation(reduceMotion ? nil : .snappy) {
                                viewModel.toggle(strip)
                            }
                        }
                    )
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
}

#Preview("Métro 1 — trafic interrompu") {
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

#Preview("RER A — tronc commun et branches") {
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
                lineID: PreviewLineStatusRepository.rerA.id
            ),
            route: PreviewLineStatusRepository.rerA
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
