import SwiftUI

struct StationDeparturesView: View {
    let station: StationMapItem
    let account: AccountModel
    let onClose: () -> Void

    @State private var viewModel: DeparturesViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(
        station: StationMapItem,
        viewModel: DeparturesViewModel,
        account: AccountModel,
        onClose: @escaping () -> Void
    ) {
        self.station = station
        self.account = account
        self.onClose = onClose
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    StationRoutesView(routes: station.routes)

                    departuresContent
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .sheetContentVisibility()
            .textSelection(.enabled)
            .navigationTitle(station.name)
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(
                        account.isFavorite(stationID: station.id)
                            ? "Retirer des favoris"
                            : "Ajouter aux favoris",
                        systemImage: account.isFavorite(stationID: station.id)
                            ? "star.fill"
                            : "star"
                    ) {
                        account.toggleFavorite(
                            stationID: station.id,
                            name: station.name,
                            coordinate: station.coordinate
                        )
                    }
                    .labelStyle(.iconOnly)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer", systemImage: "xmark", action: onClose)
                        .labelStyle(.iconOnly)
                }
            }
        }
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            viewModel.setSceneActive(phase == .active)
        }
        .sensoryFeedback(.selection, trigger: account.isFavorite(stationID: station.id))
    }

    @ViewBuilder
    private var departuresContent: some View {
        switch viewModel.state {
        case .idle:
            DepartureLoadingView(routeCount: station.routes.count)

        case .loading(let previous):
            if let previous {
                VStack(alignment: .leading, spacing: 12) {
                    ViaLoadingStatus(label: "Actualisation des passages…")
                    DepartureBoardView(routes: station.routes, board: previous)
                }
            } else {
                DepartureLoadingView(routeCount: station.routes.count)
            }

        case .loaded(let board):
            DepartureBoardView(routes: station.routes, board: board)

        case .failed(let error, let previous):
            if let previous {
                DepartureRefreshWarningView()
                DepartureBoardView(routes: station.routes, board: previous)
            } else {
                DepartureErrorView(error: error, retry: viewModel.retry)
            }
        }
    }
}

#Preview {
    let dependencies = PreviewDependencies()
    let station = StationsArea.mapPreview.mapItems[0]
    let route = station.routes[0]
    let board = DepartureBoard(
        source: .realtime,
        generatedAt: .now,
        groups: [
            DepartureGroup(
                route: route,
                destination: "La Défense",
                departures: [
                    .now.addingTimeInterval(180),
                    .now.addingTimeInterval(480),
                    .now.addingTimeInterval(840),
                ]
            ),
        ]
    )

    StationDeparturesView(
        station: station,
        viewModel: DeparturesViewModel(
            stationID: station.id,
            repository: InMemoryDeparturesRepository(board: board)
        ),
        account: dependencies.account,
        onClose: {}
    )
}
