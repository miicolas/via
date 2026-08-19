import MapKit
import SwiftUI

struct JourneyRouteMapContent: MapContent {
    let presentation: JourneyMapPresentation

    var body: some MapContent {
        ForEach(presentation.segments) { segment in
            MapPolyline(coordinates: segment.coordinates.map(\.clLocationCoordinate))
                .stroke(
                    segment.isWalking
                        ? Color.secondary.opacity(0.75)
                        : Color(transitHex: segment.colorHex ?? "", fallback: .accentColor),
                    style: StrokeStyle(
                        lineWidth: segment.isWalking ? 4 : 7,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: segment.isWalking ? [3, 7] : []
                    )
                )
                .mapOverlayLevel(level: .aboveRoads)
        }
    }
}
