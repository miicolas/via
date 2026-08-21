import SwiftUI

struct StationsView: View {
    let viewModel: StationsViewModel
    let selectedStation: SelectedStationModel

    @Binding var isLargeScreen: Bool
    @Binding var detailDetent: PresentationDetent
    let profileModel: ProfileModel

    let onOpenSearch: () -> Void
    let naturalLanguageAccess: NaturalLanguageAccess
    let showsNaturalSearchDiscovery: Bool
    let onOpenNaturalSearch: () -> Void
    let onOpenProfile: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedPlaceShortcut: StationPlaceShortcut?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Stations")
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbar {
                    // Two glass containers rather than one group: Apple
                    // Intelligence and the account are unrelated errands, and
                    // sharing a capsule made the orb read as part of the avatar.
                    if naturalLanguageAccess != .hidden {
                        ToolbarItem(placement: .topBarTrailing) {
                            AIEntryButton(
                                surface: .toolbar,
                                isDiscoverable: showsNaturalSearchDiscovery,
                                action: onOpenNaturalSearch,
                            )
                        }
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        AccountMenuButton(
                            profile: profileModel,
                            onOpenProfile: onOpenProfile,
                            onOpenSettings: onOpenSettings
                        )
                    }
                }
        }
        .opacity(tabVisibilityProgress)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.runAutomaticRefresh()
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .sheet(isPresented: selectedStationPresentation) {
            if selectedStation.overview != nil {
                StationDetailView(
                    selection: selectedStation,
                    isLargeScreen: isLargeScreen,
                    detailDetent: $detailDetent,
                )
            }
        }
    }

    private var content: some View {
        SkeletonGate(isLoading: isInitialLoading) {
            loadingContent
        } content: {
            settledContent
        }
    }

    /// Only the first load gets a skeleton — a refresh keeps the stations on
    /// screen and says so inline instead.
    private var isInitialLoading: Bool {
        switch viewModel.state {
        case .idle, .locating: true
        case let .loading(previous): previous == nil
        case .loaded, .empty, .locationUnavailable, .failed: false
        }
    }

    @ViewBuilder
    private var settledContent: some View {
        switch viewModel.state {
        case .idle, .locating:
            EmptyView()
        case let .loading(previous):
            if let previous {
                stationList(previous, isRefreshing: true)
            } else {
                EmptyView()
            }
        case let .loaded(station):
            stationList(station)
        case .empty:
            emptyContent
        case let .locationUnavailable(authorization):
            unavailableContent(for: authorization)
        case let .failed(error, previous):
            if let previous {
                stationList(previous, refreshError: error)
            } else {
                errorContent(for: error)
            }
        }
    }

    private var loadingContent: some View {
        SkeletonList(
            count: 5,
            label: "Recherche de stations…",
            row: .departure,
            separator: .divider(leadingInset: 52),
        )
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func stationList(
        _ station: StationOverview,
        isRefreshing: Bool = false,
        refreshError: ViaError? = nil,
    ) -> some View {
        List {
            StationPlacePicker(selection: $selectedPlaceShortcut)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            Button {
                detailDetent = isLargeScreen ? .fraction(0.97) : .large
                selectedStation.select(station)
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
                    LoadingStatus(label: "Actualisation…")
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if let refreshError {
                StationRefreshStatusView(
                    message: message(for: refreshError),
                    onRetry: viewModel.retry,
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

    private var emptyContent: some View {
        stateContent(EmptyState(title: "Trouvez une station"), onRetry: nil)
    }

    private func unavailableContent(for authorization: LocationAuthorization) -> some View {
        stateContent(
            EmptyState(
                title: "Localisation indisponible",
                message: message(for: authorization),
            ),
            onRetry: viewModel.retry,
        )
    }

    private func errorContent(for error: ViaError) -> some View {
        stateContent(
            EmptyState(
                title: "Stations indisponibles",
                message: message(for: error),
            ),
            onRetry: viewModel.retry,
        )
    }

    /// Every dead end on this screen points at the same place: Search is the
    /// only way to reach a station when the map cannot supply one. No glyph —
    /// the sentence already carries the one symbol that matters.
    private func stateContent(_ state: EmptyState, onRetry: (() -> Void)?) -> some View {
        EmptyStateView(state) {
            Text("Utilisez Recherche pour trouver une station près de vous.")
                .emptyStateHint()

            Button("Rechercher", systemImage: "magnifyingglass", action: onOpenSearch)
                .primaryAction()

            if let onRetry {
                RetryButton(action: onRetry)
                    .secondaryAction()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            "La configuration de Metyro est invalide."
        case .invalidRequest:
            "La zone de recherche n’est pas valide."
        case .unauthorized:
            "La connexion à Metyro n’est pas autorisée."
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

    private var selectedStationPresentation: Binding<Bool> {
        Binding(
            get: { selectedStation.overview != nil },
            set: { isPresented in
                if !isPresented {
                    selectedStation.dismiss()
                }
            },
        )
    }
}

#Preview("Station row") {
    let locationModel = LocationModel(
        adapter: InMemoryLocationAdapter(
            coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470),
        ),
    )
    let accountModel: AccountModel = {
        let model = AccountModel(
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false,
        )
        model.activateAnonymous()
        return model
    }()

    StationsView(
        viewModel: StationsViewModel(
            locationModel: locationModel,
            networkRepository: InMemoryNetworkRepository.mapPreview,
            departuresRepository: InMemoryDeparturesRepository.stationsPreview,
        ),
        selectedStation: SelectedStationModel(
            departuresRepository: InMemoryDeparturesRepository.stationsPreview,
            account: accountModel,
            locationModel: locationModel,
        ),
        isLargeScreen: .constant(false),
        detailDetent: .constant(.large),
        profileModel: ProfileModel(store: InMemoryProfileStore()),
        onOpenSearch: {},
        naturalLanguageAccess: .active,
        showsNaturalSearchDiscovery: true,
        onOpenNaturalSearch: {},
        onOpenProfile: {},
        onOpenSettings: {}
    )
}
