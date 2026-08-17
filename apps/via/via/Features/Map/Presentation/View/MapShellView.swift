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
    @State private var showTabSheet: Bool = true
    @State private var activeTab: MapShellTab = .stations
    @State private var selectedStation: StationPlaceholder?

    @State private var isLargeScreen: Bool = false
    @State private var activeDetent: PresentationDetent = .height(90)
    @State private var detailSheetDetent: PresentationDetent = .height(80)

    var body: some View {
        Map(initialPosition: .region(.paris))
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
                            isLargeScreen: $isLargeScreen,
                            selectedStation: $selectedStation,
                            detailDetent: $detailSheetDetent
                        )
                    } label: {
                        MapShellTab.stations.tabLabel
                    }

                    Tab(value: .lines) {
                        LinesView()
                    } label: {
                        MapShellTab.lines.tabLabel
                    }

                    Tab(value: .me) {
                        MeView()
                    } label: {
                        MapShellTab.me.tabLabel
                    }

                    Tab(value: MapShellTab.search, role: .search) {
                        SearchView()
                    }
                }
                .adaptiveSheet(380, isActive: isLargeScreen)
            }
            .onGeometryChange(for: Bool.self) {
                $0.size.width > 600
            } action: { newValue in
                // Remap detents before the size class flips so the sheet lands on a valid one.
                if activeDetent != .height(90) && newValue {
                    activeDetent = .fraction(0.97)
                } else if activeDetent == .fraction(0.97) && !newValue {
                    activeDetent = .fraction(0.45)
                } else {
                    activeDetent = .height(90)
                }

                if detailSheetDetent != .height(80) && newValue {
                    detailSheetDetent = .fraction(0.97)
                } else if detailSheetDetent != .height(80) && !newValue {
                    detailSheetDetent = .large
                } else {
                    detailSheetDetent = .height(80)
                }

                isLargeScreen = newValue
            }
    }
}

#Preview {
    MapShellView()
}
