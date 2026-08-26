import CoreLocation
@preconcurrency import MapKit

struct MapKitDirectJourneyRouter: DirectJourneyRouter, Sendable {
    func routes(for request: JourneyRequest) async -> [Journey] {
        guard request.requiredModes.isEmpty else { return [] }

        return await Self.calculateRoutes(for: request)
    }

    @MainActor
    private static func calculateRoutes(for request: JourneyRequest) async -> [Journey] {
        async let walking = calculate(.walking, for: request)

        guard !request.requiresAccessibleStations,
              !request.requiresOperationalElevators
        else {
            let route = await walking
            return route.map { [$0] } ?? []
        }

        async let cycling = calculate(.cycling, for: request)
        let walkingRoute = await walking
        let cyclingRoute = await cycling
        return [walkingRoute, cyclingRoute].compactMap { $0 }
    }

    @MainActor
    private static func calculate(_ mode: Mode, for request: JourneyRequest) async -> Journey? {
        do {
            try Task.checkCancellation()

            let directionsRequest = MKDirections.Request()
            directionsRequest.source = mapItem(for: request.origin)
            directionsRequest.destination = mapItem(for: request.destination.coordinate)
            directionsRequest.transportType = mode.transportType
            directionsRequest.requestsAlternateRoutes = false
            if let requestedAt = request.requestedAt {
                if request.datetimeRepresents == .arrival {
                    directionsRequest.arrivalDate = requestedAt
                } else {
                    directionsRequest.departureDate = requestedAt
                }
            }

            let response = try await MKDirections(request: directionsRequest).calculate()
            try Task.checkCancellation()

            guard let route = response.routes.first,
                  route.expectedTravelTime.isFinite,
                  route.expectedTravelTime > 0
            else {
                return nil
            }

            return journey(for: route, mode: mode, request: request)
        } catch {
            // A direct route is an enrichment. A MapKit failure must leave the
            // server's transit result, or the other direct mode, available.
            return nil
        }
    }

    @MainActor
    private static func mapItem(for coordinate: GeoCoordinate) -> MKMapItem {
        MKMapItem(
            location: CLLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ),
            address: nil
        )
    }

    @MainActor
    private static func journey(
        for route: MKRoute,
        mode: Mode,
        request: JourneyRequest
    ) -> Journey {
        let duration = max(1, Int(route.expectedTravelTime.rounded()))
        let anchor = request.requestedAt ?? .now
        let departureAt = request.datetimeRepresents == .arrival
            ? anchor.addingTimeInterval(-TimeInterval(duration))
            : anchor
        let arrivalAt = departureAt.addingTimeInterval(TimeInterval(duration))
        let origin = JourneyPlace(name: "Départ", coordinate: request.origin)
        let destination = JourneyPlace(
            name: request.destination.name,
            coordinate: request.destination.coordinate
        )
        let section = JourneySection(
            id: "mapkit:\(mode.rawValue):section",
            timingSource: .theoretical,
            kind: mode.sectionKind,
            durationSeconds: duration,
            from: origin,
            to: destination,
            departureAt: departureAt,
            arrivalAt: arrivalAt,
            scheduledDepartureAt: departureAt,
            scheduledArrivalAt: arrivalAt,
            geometry: geometry(
                for: route,
                fallback: [request.origin, request.destination.coordinate]
            ),
            route: nil,
            direction: nil,
            platform: nil,
            stops: []
        )

        return Journey(
            id: JourneyID(rawValue: journeyID(for: mode, request: request)),
            qualifier: mode.qualifier,
            durationSeconds: duration,
            walkingDurationSeconds: mode == .walking ? duration : 0,
            transferCount: 0,
            departureAt: departureAt,
            arrivalAt: arrivalAt,
            status: .theoretical,
            warnings: [],
            sections: [section]
        )
    }

    @MainActor
    private static func geometry(
        for route: MKRoute,
        fallback: [GeoCoordinate]
    ) -> [GeoCoordinate] {
        guard route.polyline.pointCount >= 2 else { return fallback }

        let points = route.polyline.points()
        return (0..<route.polyline.pointCount).map { index in
            let coordinate = points[index].coordinate
            return GeoCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }

    private static func journeyID(for mode: Mode, request: JourneyRequest) -> String {
        let origin = "\(request.origin.latitude),\(request.origin.longitude)"
        let destination = "\(request.destination.coordinate.latitude),\(request.destination.coordinate.longitude)"
        return "mapkit:\(mode.rawValue):\(origin):\(destination)"
    }
}

private extension MapKitDirectJourneyRouter {
    enum Mode: String, Sendable, Equatable {
        case walking
        case cycling

        var transportType: MKDirectionsTransportType {
            switch self {
            case .walking: .walking
            case .cycling: .cycling
            }
        }

        var qualifier: Journey.Qualifier {
            switch self {
            case .walking: .walking
            case .cycling: .bike
            }
        }

        var sectionKind: JourneySection.Kind {
            switch self {
            case .walking: .walk
            case .cycling: .bike
            }
        }
    }
}
