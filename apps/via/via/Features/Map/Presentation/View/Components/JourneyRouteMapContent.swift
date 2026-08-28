import MapKit
import SwiftUI

struct JourneyRouteMapContent: MapContent {
    let presentation: JourneyMapPresentation
    var highlightedSegmentID: String?

    var body: some MapContent {
        ForEach(presentation.segments) { segment in
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
                JourneyStopAnnotationView(stop: stop, isDimmed: false)
            }
            .annotationTitles(.hidden)
        }

        ForEach(presentation.exits) { exit in
            Annotation(
                exit.name,
                coordinate: exit.coordinate.clLocationCoordinate,
                anchor: .bottom
            ) {
                JourneyExitAnnotationView(exit: exit, isDimmed: false)
            }
            .annotationTitles(.hidden)
        }
    }

    private func opacity(of segment: JourneyMapSegment) -> Double {
        guard let highlightedSegmentID,
              let highlightedSectionIndex = presentation.segments.first(where: {
                  $0.id == highlightedSegmentID
              })?.sectionIndex else { return 1 }
        return segment.sectionIndex == highlightedSectionIndex ? 1 : 0.72
    }

    /// Selection thickens the chosen section rather than erasing the others.
    private func lineWidth(of segment: JourneyMapSegment) -> Double {
        let base = segment.isPedestrian ? 2.5 : 4.5
        guard let highlightedSegmentID,
              segment.id == highlightedSegmentID || segment.id.hasPrefix("\(highlightedSegmentID):")
        else { return base }
        return base + 1.5
    }
}
