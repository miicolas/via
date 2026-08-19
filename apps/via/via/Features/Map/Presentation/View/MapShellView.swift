import MapKit
import SwiftUI

extension MKCoordinateRegion {
    static let paris = MKCoordinateRegion(
        center: .init(latitude: 48.8566, longitude: 2.3522),
        latitudinalMeters: 4000,
        longitudinalMeters: 4000
    )
}

/// Root screen: full-screen map with a persistent bottom sheet hosting the
/// Stations / Lignes / Signaler / Recherche tabs, Find My style.
struct MapShellView: View {
    let networkViewModel: NetworkViewModel
    let stationsViewModel: StationsViewModel
    let linesViewModel: LinesViewModel
    let selectedStationModel: SelectedStationModel
    let searchViewModel: SearchViewModel
    let onboardingModel: OnboardingModel
    let locationModel: LocationModel
    let reportRepository: any ReportRepository

    @State private var showTabSheet: Bool = true
    @State private var activeTab: MapShellTab = .stations
    @State private var previousTab: MapShellTab = .stations
    @State private var position: MapCameraPosition = .region(.paris)
    @State private var selectedMapStation: StationMapItem?

    @State private var isLargeScreen: Bool = false
    // The reference opens with the map still visible above the content sheet.
    @State private var activeDetent: PresentationDetent = .fraction(0.45)
    @State private var detailSheetDetent: PresentationDetent = .height(80)
    @State private var isOnboardingPresented = false

    init(
        networkViewModel: NetworkViewModel,
        stationsViewModel: StationsViewModel,
        linesViewModel: LinesViewModel,
        selectedStationModel: SelectedStationModel,
        searchViewModel: SearchViewModel,
        onboardingModel: OnboardingModel,
        locationModel: LocationModel,
        reportRepository: any ReportRepository
    ) {
        self.networkViewModel = networkViewModel
        self.stationsViewModel = stationsViewModel
        self.linesViewModel = linesViewModel
        self.selectedStationModel = selectedStationModel
        self.searchViewModel = searchViewModel
        self.onboardingModel = onboardingModel
        self.locationModel = locationModel
        self.reportRepository = reportRepository
    }

    var body: some View {
        NetworkMapView(
            viewModel: networkViewModel,
            position: $position,
            stationSelectionEnabled: activeTab != .search,
            journeyPresentation: activeTab == .search ? searchViewModel.mapPresentation : nil,
            selectedStation: $selectedMapStation
        )
            // Keeps the Apple legal attribution above the collapsed sheet.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(height: 65)
            }
            .sheet(isPresented: $showTabSheet) {
                SheetTabView(
                    selection: $activeTab,
                    activeDetent: $activeDetent,
                    isLargeScreen: isLargeScreen,
                    isAnotherSheetPresenting: selectedStationModel.overview != nil
                ) {
                    Tab(value: .stations) {
                        StationsView(
                            viewModel: stationsViewModel,
                            selectedStation: selectedStationModel,
                            isLargeScreen: $isLargeScreen,
                            detailDetent: $detailSheetDetent,
                            onOpenSearch: { activeTab = .search }
                        )
                    } label: {
                        MapShellTab.stations.tabLabel
                    }

                    Tab(value: .lines) {
                        LinesView(viewModel: linesViewModel)
                    } label: {
                        MapShellTab.lines.tabLabel
                    }

                    Tab(value: .report) {
                        ReportView(
                            locationModel: locationModel,
                            repository: reportRepository
                        )
                    } label: {
                        MapShellTab.report.tabLabel
                    }

                    Tab(value: MapShellTab.search, role: .search) {
                        SearchView(
                            viewModel: searchViewModel,
                            onClose: closeSearch
                        )
                    }
                }
                .adaptiveSheet(380, isActive: isLargeScreen)
                .sheet(isPresented: $isOnboardingPresented) {
                    OnboardingView(model: onboardingModel)
                }
            }
            .onChange(of: selectedMapStation) { _, newValue in
                guard let newValue else { return }
                // Clear right away so re-tapping the same annotation reopens the sheet.
                selectedMapStation = nil
                activeTab = .stations
                detailSheetDetent = isLargeScreen ? .fraction(0.97) : .large
                selectedStationModel.select(newValue)
            }
            .onChange(of: searchViewModel.mapPresentation) { _, presentation in
                guard activeTab == .search, let mapRect = presentation?.mapRect else { return }
                position = .rect(mapRect)
            }
            .onChange(of: activeTab) { oldValue, newValue in
                if newValue == .search, oldValue != .search {
                    previousTab = oldValue
                    activeDetent = isLargeScreen ? .fraction(0.97) : .large
                } else if newValue == .report, oldValue != .report {
                    activeDetent = isLargeScreen ? .fraction(0.97) : .large
                } else if oldValue == .search, newValue != .search {
                    activeDetent = isLargeScreen ? .fraction(0.97) : .fraction(0.45)
                } else if oldValue == .report, newValue != .report {
                    activeDetent = isLargeScreen ? .fraction(0.97) : .fraction(0.45)
                }
            }
            .onGeometryChange(for: Bool.self) {
                $0.size.width > 600
            } action: { newValue in
                // Remap detents before the size class flips so the sheet lands on a valid one.
                if newValue && activeDetent != .height(90) {
                    activeDetent = .fraction(0.97)
                } else if !newValue && activeDetent == .fraction(0.97) {
                    activeDetent = .fraction(0.45)
                }

                if newValue && detailSheetDetent != .height(80) {
                    detailSheetDetent = .fraction(0.97)
                } else if !newValue && detailSheetDetent == .fraction(0.97) {
                    detailSheetDetent = .large
                }

                isLargeScreen = newValue
            }
            .task {
                guard !onboardingModel.isCompleted else { return }
                isOnboardingPresented = true
            }
    }

    private func closeSearch() {
        activeTab = previousTab
    }
}

#Preview {
    let locationModel = LocationModel(
        adapter: InMemoryLocationAdapter(
            coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470)
        )
    )
    let accountModel: AccountModel = {
        let model = AccountModel(
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false
        )
        model.activateAnonymous()
        return model
    }()
    let departures = InMemoryDeparturesRepository.stationsPreview

    MapShellView(
        networkViewModel: NetworkViewModel(repository: InMemoryNetworkRepository.mapPreview),
        stationsViewModel: StationsViewModel(
            locationModel: locationModel,
            networkRepository: InMemoryNetworkRepository.mapPreview,
            departuresRepository: departures
        ),
        linesViewModel: LinesViewModel(repository: PreviewLineStatusRepository()),
        selectedStationModel: SelectedStationModel(
            departuresRepository: departures,
            account: accountModel,
            locationModel: locationModel
        ),
        searchViewModel: SearchViewModel(
            repository: InMemorySearchRepository.preview,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
            locationModel: locationModel,
            account: accountModel
        ),
        onboardingModel: OnboardingModel(store: OnboardingStore(defaults: .standard)),
        locationModel: locationModel,
        reportRepository: InMemoryReportRepository()
    )
}
