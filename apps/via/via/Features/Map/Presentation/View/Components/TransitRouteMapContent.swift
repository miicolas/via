import MapKit
import SwiftUI

struct TransitRouteMapContent: MapContent {
    let routes: [NetworkRoute]
    let opacity: Double
    let lineWidth: Double

    var body: some MapContent {
        ForEach(routes) { route in
            ForEach(route.segments) { segment in
                MapPolyline(
                    coordinates: segment.coordinates.map(\.clLocationCoordinate)
                )
                .stroke(
                    Color(
                        transitHex: route.badge.colorHex,
                        fallback: .secondary
                    ).opacity(opacity),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .mapOverlayLevel(level: .aboveRoads)
            }
        }
    }
}
