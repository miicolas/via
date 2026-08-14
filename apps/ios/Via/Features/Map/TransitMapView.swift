import MapKit
import SwiftUI

struct TransitMapView: View {
    let model: MapFeatureModel
    @Binding var position: MapCameraPosition

    var body: some View {
        Map(position: $position) {
            ForEach(model.mapRoutes) { route in
                ForEach(route.segments) { segment in
                    MapPolyline(coordinates: segment.coordinates.map(\.clCoordinate))
                        .stroke(
                            Color(hex: route.color),
                            lineWidth: route.mode == .bus ? 2 : 5
                        )
                }
            }

            ForEach(Array(model.mapStations.prefix(1_500))) { station in
                Annotation(station.name, coordinate: station.coordinate.clCoordinate) {
                    StationMarkerView(
                        station: station,
                        routes: routes(for: station),
                        isSelected: model.selectedStation?.id == station.id
                    )
                    .onTapGesture {
                        model.selectStation(station)
                    }
                }
            }

            if model.locationProvider.shouldDisplayUserLocation,
               model.locationState.canDisplayUserLocation {
                UserAnnotation()
            }
        }
        .mapStyle(.standard)
        .mapControls {
            if model.locationProvider.shouldDisplayUserLocation,
               model.locationState.canDisplayUserLocation {
                MapUserLocationButton()
            }
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            model.reportViewport(
                ViewportRegion(
                    latitude: context.region.center.latitude,
                    longitude: context.region.center.longitude,
                    latitudeDelta: context.region.span.latitudeDelta,
                    longitudeDelta: context.region.span.longitudeDelta
                )
            )
        }
        .ignoresSafeArea()
    }

    private func routes(for station: NetworkStation) -> [RouteBadge] {
        station.routeIds.compactMap { id in
            model.mapRoutes.first(where: { $0.id == id }).map {
                RouteBadge(
                    id: $0.id,
                    shortName: $0.shortName,
                    mode: $0.mode,
                    color: $0.color,
                    textColor: $0.textColor
                )
            }
        }
    }
}
