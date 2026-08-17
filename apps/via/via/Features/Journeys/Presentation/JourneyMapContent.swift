import MapKit
import SwiftUI

struct JourneyMapContent: MapContent {
    let presentation: JourneyMapPresentation

    var body: some MapContent {
        if presentation.journey != nil {
            ForEach(presentation.drawableSections) { section in
                MapPolyline(coordinates: section.geometry.map(\.clLocationCoordinate))
                    .stroke(
                        color(for: section),
                        style: StrokeStyle(
                            lineWidth: section.kind == .transit ? 7 : 5,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: section.kind == .transit ? [] : [8, 7]
                        )
                    )
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }

        Annotation(
            "Départ",
            coordinate: presentation.origin.clLocationCoordinate,
            anchor: .center
        ) {
            endpointMarker(color: .blue, systemImage: "location.fill")
        }
        .annotationTitles(.hidden)

        Annotation(
            "Arrivée",
            coordinate: presentation.destination.clLocationCoordinate,
            anchor: .bottom
        ) {
            endpointMarker(color: .red, systemImage: "mappin")
        }
        .annotationTitles(.hidden)
    }

    private func color(for section: JourneySection) -> Color {
        guard section.kind == .transit, let route = section.route else {
            return .secondary
        }
        return Color(transitHex: route.colorHex, fallback: .blue)
    }

    private func endpointMarker(color: Color, systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: Circle())
            .overlay {
                Circle().strokeBorder(.white, lineWidth: 3)
            }
            .shadow(radius: 3, y: 1)
    }
}
