import MapKit
import SwiftUI

struct JourneyRouteMapContent: MapContent {
    let presentation: JourneyMapPresentation
    var progress: JourneyProgress?
    var highlightedSegmentID: String?

    var body: some MapContent {
        ForEach(presentation.rendered(with: progress)) { segment in
            if segment.isStationary, let coordinate = segment.coordinates.first {
                MapCircle(center: coordinate.clLocationCoordinate, radius: 45)
                    .foregroundStyle(Color.secondary.opacity(0.35 * opacity(of: segment)))
                    .mapOverlayLevel(level: .aboveRoads)
            } else {
                MapPolyline(coordinates: segment.coordinates.map(\.clLocationCoordinate))
                    .stroke(
                        segment.isPedestrian
                            ? Color.secondary.opacity(0.75 * opacity(of: segment))
                            : Color(transitHex: segment.colorHex ?? "", fallback: .accentColor)
                                .opacity(opacity(of: segment)),
                        style: StrokeStyle(
                            lineWidth: lineWidth(of: segment),
                            lineCap: .round,
                            lineJoin: .round,
                            dash: segment.isPedestrian ? [3, 7] : []
                        )
                    )
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }

        ForEach(presentation.stops) { stop in
            Annotation(stop.name, coordinate: stop.coordinate.clLocationCoordinate, anchor: .center) {
                JourneyStopAnnotationView(stop: stop, isDimmed: isTravelled(stop))
            }
            .annotationTitles(.hidden)
        }
    }

    /// Only what is behind the traveller fades. Dimming everything but the
    /// current section — the previous behaviour — made the route unreadable.
    private func opacity(of segment: JourneyRenderedSegment) -> Double {
        segment.isTravelled ? 0.3 : 1
    }

    /// Selection thickens the chosen section rather than erasing the others.
    private func lineWidth(of segment: JourneyRenderedSegment) -> Double {
        let base = segment.isPedestrian ? 4.0 : 7.0
        guard let highlightedSegmentID,
              segment.id == highlightedSegmentID || segment.id.hasPrefix("\(highlightedSegmentID):")
        else { return base }
        return base + 3
    }

    private func isTravelled(_ stop: JourneyMapStop) -> Bool {
        guard let progress else { return false }
        return stop.sectionIndex < progress.sectionIndex
    }
}
