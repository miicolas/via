import SwiftUI

struct MapPresentationState {
    static let collapsedDetent = PresentationDetent.height(95)
    static let searchDetent = PresentationDetent.fraction(0.45)

    private(set) var destination: MapPresentationDestination = .search
    private(set) var selectedDetent: PresentationDetent = searchDetent
    var searchText = ""

    var selectedStation: StationMapItem? {
        destination.station
    }

    mutating func selectMapStation(_ station: StationMapItem?) {
        switch destination {
        case .search:
            guard let station else { return }
            destination = .station(station)
            selectedDetent = .medium

        case .station:
            guard station == nil else { return }
            showSearch()
        }
    }

    mutating func selectDetent(_ detent: PresentationDetent) {
        selectedDetent = detent

        if case .station = destination, detent == Self.collapsedDetent {
            destination = .search
        }
    }

    mutating func showSearch() {
        destination = .search
        selectedDetent = Self.collapsedDetent
    }
}
