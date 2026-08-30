import SwiftUI

struct StationsView: View {
    let viewModel: StationsViewModel
    /// Absent in previews and tests, where the tab is still the single nearest
    /// station it used to be.
    let nearby: NearbyStationsModel?
    let selectedStation: SelectedStationModel
    let accountModel: AccountModel

    @Binding var isLargeScreen: Bool
    @Binding var detailDetent: PresentationDetent
    let profileModel: ProfileModel

    let onSelectNearby: (StationMapItem) -> Void
    let onOpenSearch: () -> Void
    let naturalLanguageAccess: NaturalLanguageAccess
    let showsNaturalSearchDiscovery: Bool
    let onOpenNaturalSearch: () -> Void
    let onOpenProfile: () -> Void
    let onOpenMeetups: () -> Void
    let onOpenFriends: () -> Void
    let onOpenSettings: () -> Void
    let onMeetAtStation: (StationOverview) -> Void
    let onOpenSavedDestination: (SearchResult) -> Void
    let onConfigurePlace: (SavedPlace.Role) -> Void
    let onAddSavedDestination: () -> Void
    let onEditPlace: (SavedPlace) -> Void
    let onEditSavedDestination: (SavedDestination) -> Void
    let onManageSavedDestinations: () -> Void

    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress
    @Environment(\.scenePhase) private var scenePhase

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
                            onOpenMeetups: onOpenMeetups,
                            onOpenFriends: onOpenFriends,
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
                    onMeetHere: onMeetAtStation
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
        if let nearby {
            guard nearby.transitResults.isEmpty else { return false }
            switch nearby.loading {
            // `.idle` means the map has not reported a centre yet — still a
            // first load, not an answer.
            case .idle, .loading: return true
            case .loaded, .failed: return false
            }
        }
        switch viewModel.state {
        case .idle, .locating: return true
        case let .loading(previous): return previous == nil
        case .loaded, .empty, .locationUnavailable, .failed: return false
        }
    }

    @ViewBuilder
    private var settledContent: some View {
        if let nearby {
            nearbyContent(nearby)
        } else {
            singleStationContent
        }
    }

    /// The tab as a nearby list: whatever matches the filter within
    /// `NearbyStationsModel.radiusMeters` of the map's centre, nearest first.
    /// The leading station keeps its departure board; the rest say where they
    /// are and why they matched, because a board is one request per station.
    @ViewBuilder
    private func nearbyContent(_ nearby: NearbyStationsModel) -> some View {
        if nearby.transitResults.isEmpty {
            if case let .failed(error) = nearby.loading {
                errorContent(for: error)
            } else if nearby.filter.isActive {
                filteredContent(nearby)
            } else {
                emptyContent
            }
        } else {
            nearbyList(nearby)
        }
    }

    private func nearbyList(_ nearby: NearbyStationsModel) -> some View {
        let hero = viewModel.state.overview
        let others = nearby.transitResults.filter { $0.id != hero?.id }

        return List {
            placePicker

            if let hero {
                Section {
                    Button {
                        detailDetent = isLargeScreen ? .fraction(0.97) : .large
                        selectedStation.select(hero)
                    } label: {
                        StationRowLabel(station: hero)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            if !others.isEmpty {
                Section("À proximité") {
                    ForEach(others) { station in
                        NearbyStationRow(station: station, filter: nearby.filter) {
                            onSelectNearby(station.item)
                        }
                        .listRowInsets(
                            EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                        )
                        .listRowBackground(Color.clear)
                    }
                }
            }

            if case let .failed(error) = nearby.loading {
                StationRefreshStatusView(
                    message: message(for: error),
                    onRetry: viewModel.retry,
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .hapticRefreshable {
            await viewModel.refresh()
        }
    }

    /// Everything is there, the filter is hiding it. The way out is the map's
    /// own filter control, so the sentence points at it rather than repeating
    /// it as a button this screen does not own.
    private func filteredContent(_ nearby: NearbyStationsModel) -> some View {
        EmptyStateView(
            .filtered(
                title: "Aucune station ne correspond",
                message: nearby.matchesBeforeFilter > 0
                    ? "\(nearby.matchesBeforeFilter) stations autour de ce point, aucune ne réunit les critères choisis."
                    : "Aucune station autour de ce point. Déplacez la carte pour explorer une autre zone."
            )
        ) {
            EmptyStateHint(
                Text("Touchez \(Image(systemName: "line.3.horizontal.decrease")) sur la carte pour changer les filtres"),
                label: "Ouvrir les filtres de la carte",
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var singleStationContent: some View {
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
            placePicker

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
        .hapticRefreshable {
            await viewModel.refresh()
        }
    }

    private var placePicker: some View {
        SavedPlacesBar(
            places: accountModel.places,
            destinations: accountModel.destinations,
            selectionAccessibilityHint: "Calcule un trajet depuis votre position",
            onSelectPlace: { onOpenSavedDestination($0.searchResult) },
            onSelectDestination: { onOpenSavedDestination($0.searchResult) },
            onConfigure: onConfigurePlace,
            onAdd: onAddSavedDestination,
            onEditPlace: onEditPlace,
            onEditDestination: onEditSavedDestination,
            onClearPlace: { accountModel.removePlace(for: $0) },
            onRemoveDestination: { accountModel.removeDestination(id: $0) },
            onManage: onManageSavedDestinations
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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
            EmptyStateHint(
                Text("Touchez \(Image(systemName: "magnifyingglass.circle.fill")) Recherche pour trouver une station près de vous"),
                label: "Ouvrir Recherche pour trouver une station",
                action: onOpenSearch,
            )

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
        nearby: nil,
        selectedStation: SelectedStationModel(
            departuresRepository: InMemoryDeparturesRepository.stationsPreview,
            crowdingRepository: InMemoryStationCrowdingRepository(crowding: .preview),
            reportRepository: InMemoryReportRepository(),
            account: accountModel,
            locationModel: locationModel,
        ),
        accountModel: accountModel,
        isLargeScreen: .constant(false),
        detailDetent: .constant(.large),
        profileModel: ProfileModel(store: InMemoryProfileStore()),
        onSelectNearby: { _ in },
        onOpenSearch: {},
        naturalLanguageAccess: .active,
        showsNaturalSearchDiscovery: true,
        onOpenNaturalSearch: {},
        onOpenProfile: {},
        onOpenMeetups: {},
        onOpenFriends: {},
        onOpenSettings: {},
        onMeetAtStation: { _ in },
        onOpenSavedDestination: { _ in },
        onConfigurePlace: { _ in },
        onAddSavedDestination: {},
        onEditPlace: { _ in },
        onEditSavedDestination: { _ in },
        onManageSavedDestinations: {}
    )
}
