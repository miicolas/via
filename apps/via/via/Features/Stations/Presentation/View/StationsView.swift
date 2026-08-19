import SwiftUI

struct StationsView: View {
    let viewModel: StationsViewModel
    let account: AccountModel?

    @Binding var isLargeScreen: Bool
    @Binding var selectedStation: StationOverview?
    @Binding var detailDetent: PresentationDetent

    let onOpenSearch: () -> Void
    let onOpenProfile: () -> Void

    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedPlaceShortcut: StationPlaceShortcut?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Stations")
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: onOpenProfile) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Profil")
                    }
                }
        }
        .opacity(tabVisibilityProgress)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.runAutomaticRefresh()
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .sheet(item: $selectedStation) { station in
            StationDetailView(
                station: station,
                viewModel: viewModel,
                account: account,
                isLargeScreen: isLargeScreen,
                detailDetent: $detailDetent
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .locating:
            loadingContent
        case .loading(let previous):
            if let previous {
                stationList(previous, isRefreshing: true)
            } else {
                loadingContent
            }
        case .loaded(let station):
            stationList(station)
        case .empty:
            StationsEmptyStateView(onOpenSearch: onOpenSearch)
        case .locationUnavailable(let authorization):
            unavailableContent(for: authorization)
        case .failed(let error, let previous):
            if let previous {
                stationList(previous, refreshError: error)
            } else {
                errorContent(for: error)
            }
        }
    }

    private var loadingContent: some View {
        VStack {
            Spacer()
            ViaLoadingStatus(label: "Recherche de stations…")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func stationList(
        _ station: StationOverview,
        isRefreshing: Bool = false,
        refreshError: ViaError? = nil
    ) -> some View {
        List {
            StationPlacePicker(selection: $selectedPlaceShortcut)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            Button {
                detailDetent = isLargeScreen ? .fraction(0.97) : .large
                selectedStation = station
            } label: {
                StationRowLabel(station: station)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            if isRefreshing {
                HStack {
                    Spacer()
                    ViaLoadingStatus(label: "Actualisation…")
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if let refreshError {
                StationRefreshStatusView(
                    message: message(for: refreshError),
                    onRetry: viewModel.retry
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.refresh()
        }
    }

    private func unavailableContent(for authorization: LocationAuthorization) -> some View {
        StationsEmptyStateView(
            title: "Localisation indisponible",
            message: message(for: authorization),
            onOpenSearch: onOpenSearch,
            onRetry: viewModel.retry
        )
    }

    private func errorContent(for error: ViaError) -> some View {
        StationsEmptyStateView(
            title: "Stations indisponibles",
            message: message(for: error),
            onOpenSearch: onOpenSearch,
            onRetry: viewModel.retry
        )
    }

    private func message(for authorization: LocationAuthorization) -> String {
        switch authorization {
        case .notDetermined:
            "Autorisez la localisation ou recherchez une station manuellement."
        case .restricted:
            "La localisation est limitée sur cet appareil."
        case .denied:
            "La localisation n’est pas disponible. Recherchez une station manuellement."
        case .authorized:
            "La position est en cours de recherche."
        }
    }

    private func message(for error: ViaError) -> String {
        switch error {
        case .invalidConfiguration:
            "La configuration de Via est invalide."
        case .invalidRequest:
            "La zone de recherche n’est pas valide."
        case .unauthorized:
            "La connexion à Via n’est pas autorisée."
        case .rateLimited:
            "Le service est momentanément limité."
        case .unavailable:
            "Le service est momentanément indisponible."
        case .server:
            "Le serveur n’a pas pu répondre."
        case .decoding, .transport:
            "Impossible de charger les stations pour le moment."
        }
    }
}

#Preview("Station row") {
    StationsView(
        viewModel: StationsViewModel(
            locationAdapter: InMemoryLocationAdapter(
                coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470)
            ),
            networkRepository: InMemoryNetworkRepository.mapPreview,
            departuresRepository: InMemoryDeparturesRepository.stationsPreview
        ),
        account: nil,
        isLargeScreen: .constant(false),
        selectedStation: .constant(nil),
        detailDetent: .constant(.large),
        onOpenSearch: {},
        onOpenProfile: {}
    )
}

#Preview("Empty state") {
    StationsEmptyStateView(onOpenSearch: {})
        .frame(height: 500)
}
