import MapKit
import SwiftUI

struct JourneyRouteMapContent: MapContent {
    let presentation: JourneyMapPresentation
    var highlightedSegmentID: String?

    var body: some MapContent {
        ForEach(presentation.segments) { segment in
            let opacity = highlightedSegmentID == nil || highlightedSegmentID == segment.id
                ? 1.0
                : 0.24
            MapPolyline(coordinates: segment.coordinates.map(\.clLocationCoordinate))
                .stroke(
                    segment.isPedestrian
                        ? Color.secondary.opacity(0.75 * opacity)
                        : Color(transitHex: segment.colorHex ?? "", fallback: .accentColor)
                            .opacity(opacity),
                    style: StrokeStyle(
                        lineWidth: segment.isPedestrian ? 4 : 7,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: segment.isPedestrian ? [3, 7] : []
                    )
                )
                .mapOverlayLevel(level: .aboveRoads)
        }
    }
}
