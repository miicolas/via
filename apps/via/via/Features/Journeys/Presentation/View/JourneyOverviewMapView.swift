import MapKit
import SwiftUI

struct JourneyOverviewMapView: View {
    let presentation: JourneyMapPresentation
    let highlightedSectionID: String?

    @State private var position: MapCameraPosition

    init(
        presentation: JourneyMapPresentation,
        highlightedSectionID: String? = nil
    ) {
        self.presentation = presentation
        self.highlightedSectionID = highlightedSectionID
        _position = State(initialValue: presentation.mapRect.map(MapCameraPosition.rect) ?? .automatic)
    }

    var body: some View {
        Map(position: $position, interactionModes: []) {
            JourneyRouteMapContent(
                presentation: presentation,
                highlightedSegmentID: highlightedSectionID
            )
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .onChange(of: highlightedSectionID) { _, sectionID in
            guard let mapRect = presentation.mapRect(for: sectionID) else { return }
            position = .rect(mapRect)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
