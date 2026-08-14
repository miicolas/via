import MapKit
import SwiftUI

struct LineDetailView: View {
    let route: NetworkRoute
    let stations: [NetworkStation]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Map(position: .constant(.automatic)) {
                    ForEach(route.segments) { segment in
                        MapPolyline(coordinates: segment.coordinates.map(\.clCoordinate))
                            .stroke(Color(hex: route.color), lineWidth: 6)
                    }

                    ForEach(stations) { station in
                        Marker(station.name, coordinate: station.coordinate.clCoordinate)
                            .tint(Color(hex: route.color))
                    }
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .mapStyle(.standard)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Carte de la ligne \(route.shortName)")

                VStack(alignment: .leading, spacing: 6) {
                    Text(route.mode == .metro ? "Métro \(route.shortName)" : route.shortName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(ViaTheme.ink)
                    Text("\(stations.count) stations desservies")
                        .font(.subheadline)
                        .foregroundStyle(ViaTheme.body)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("Stations")
                        .font(.headline)
                        .foregroundStyle(ViaTheme.ink)
                        .padding(.bottom, 8)

                    ForEach(Array(stations.enumerated()), id: \.element.id) { index, station in
                        LineStationRowView(
                            station: station,
                            route: route,
                            isLast: index == stations.count - 1
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(ViaTheme.ground)
        .navigationTitle("Ligne \(route.shortName)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
