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
/// Stations / Lines / Me / Search tabs, Find My style.
struct MapShellView: View {
    let networkViewModel: NetworkViewModel
    let stationsViewModel: StationsViewModel
    let linesViewModel: LinesViewModel
    let searchRepository: any SearchRepository
    let lineStatusRepository: any LineStatusRepository

    @State private var showTabSheet: Bool = true
    @State private var activeTab: MapShellTab = .stations
    @State private var previousTab: MapShellTab = .stations
    @State private var selectedStation: StationOverview?
    @State private var position: MapCameraPosition = .region(.paris)
    @State private var selectedMapStation: StationMapItem?

    @State private var isLargeScreen: Bool = false
    // The reference opens with the map still visible above the content sheet.
    @State private var activeDetent: PresentationDetent = .fraction(0.45)
    @State private var detailSheetDetent: PresentationDetent = .height(80)

    init(
        networkViewModel: NetworkViewModel,
        stationsViewModel: StationsViewModel,
        linesViewModel: LinesViewModel,
        searchRepository: any SearchRepository = InMemorySearchRepository.preview,
        lineStatusRepository: any LineStatusRepository = PreviewLineStatusRepository()
    ) {
        self.networkViewModel = networkViewModel
        self.stationsViewModel = stationsViewModel
        self.linesViewModel = linesViewModel
        self.searchRepository = searchRepository
        self.lineStatusRepository = lineStatusRepository
    }

    var body: some View {
        NetworkMapView(
            viewModel: networkViewModel,
            position: $position,
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
                    isAnotherSheetPresenting: selectedStation != nil
                ) {
                    Tab(value: .stations) {
                        StationsView(
                            viewModel: stationsViewModel,
                            isLargeScreen: $isLargeScreen,
                            selectedStation: $selectedStation,
                            detailDetent: $detailSheetDetent,
                            onOpenSearch: { activeTab = .search },
                            onOpenProfile: { activeTab = .me }
                        )
                    } label: {
                        MapShellTab.stations.tabLabel
                    }

                    Tab(value: .lines) {
                        LinesView(
                            viewModel: linesViewModel,
                            repository: lineStatusRepository
                        )
                    } label: {
                        MapShellTab.lines.tabLabel
                    }

                    Tab(value: .me) {
                        MeView()
                    } label: {
                        MapShellTab.me.tabLabel
                    }

                    Tab(value: MapShellTab.search, role: .search) {
                        SearchView(
                            repository: searchRepository,
                            onClose: closeSearch
                        )
                    }
                }
                .adaptiveSheet(380, isActive: isLargeScreen)
            }
            .onChange(of: selectedMapStation) { _, newValue in
                guard let newValue else { return }
                // Clear right away so re-tapping the same annotation reopens the sheet.
                selectedMapStation = nil
                activeTab = .stations
                detailSheetDetent = isLargeScreen ? .fraction(0.97) : .large
                selectedStation = stationsViewModel.selectStation(newValue)
            }
            .onChange(of: activeTab) { oldValue, newValue in
                if newValue == .search, oldValue != .search {
                    previousTab = oldValue
                    activeDetent = isLargeScreen ? .fraction(0.97) : .large
                } else if oldValue == .search, newValue != .search {
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
    }

    private func closeSearch() {
        activeTab = previousTab
    }
}

#Preview {
    let locationAdapter = InMemoryLocationAdapter(
        coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470)
    )

    MapShellView(
        networkViewModel: NetworkViewModel(repository: InMemoryNetworkRepository.mapPreview),
        stationsViewModel: StationsViewModel(
            locationAdapter: locationAdapter,
            networkRepository: InMemoryNetworkRepository.mapPreview,
            departuresRepository: InMemoryDeparturesRepository.stationsPreview
        ),
        linesViewModel: LinesViewModel(repository: PreviewLineStatusRepository())
    )
}
