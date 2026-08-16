import SwiftUI

struct StationDeparturesView: View {
    let station: StationMapItem
    let favoriteStations: any FavoriteStationRepository
    let onClose: () -> Void

    @State private var viewModel: DeparturesViewModel
    @State private var isFavorite: Bool
    @Environment(\.scenePhase) private var scenePhase

    init(
        station: StationMapItem,
        viewModel: DeparturesViewModel,
        favoriteStations: any FavoriteStationRepository,
        onClose: @escaping () -> Void
    ) {
        self.station = station
        self.favoriteStations = favoriteStations
        self.onClose = onClose
        _viewModel = State(initialValue: viewModel)
        _isFavorite = State(initialValue: favoriteStations.isFavorite(stationID: station.id))
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
            .textSelection(.enabled)
            .navigationTitle(station.name)
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(
                        isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                        systemImage: isFavorite ? "star.fill" : "star"
                    ) {
                        isFavorite = favoriteStations.toggle(
                            stationID: station.id,
                            name: station.name
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
        .sensoryFeedback(.selection, trigger: isFavorite)
    }

    @ViewBuilder
    private var departuresContent: some View {
        switch viewModel.state {
        case .idle:
            DepartureLoadingView()

        case .loading(let previous):
            if let previous {
                DepartureBoardView(routes: station.routes, board: previous)
            } else {
                DepartureLoadingView()
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
        favoriteStations: AppDependencies.preview.favoriteStations,
        onClose: {}
    )
}
