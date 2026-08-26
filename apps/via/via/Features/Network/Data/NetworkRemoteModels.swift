import Foundation

struct NetworkSegmentDTO: Decodable {
    let id: String
    let coordinates: [CoordinateDTO]
}

struct NetworkRouteDTO: Decodable {
    let id: String
    let shortName: String
    let mode: String
    let color: String
    let textColor: String
    let segments: [NetworkSegmentDTO]
}

struct NetworkStationDTO: Decodable {
    struct Accessibility: Decodable {
        let condition: String
        let label: String
        let comment: String?
    }

    struct Toilets: Decodable {
        let label: String
        let detail: String?
    }

    let id: String
    let name: String
    let coordinate: CoordinateDTO
    let routeIds: [String]
    let accessibility: Accessibility?
    let hasElevators: Bool?
    let toilets: Toilets?

    func domain() -> NetworkStation {
        NetworkStation(
            id: StationID(rawValue: id),
            name: name,
            coordinate: coordinate.domain,
            routeIDs: routeIds.map(RouteID.init(rawValue:)),
            accessibility: accessibility.flatMap { value in
                guard let condition = StationAccessibility.Condition(rawValue: value.condition) else {
                    return nil
                }
                return StationAccessibility(
                    condition: condition,
                    label: value.label,
                    comment: value.comment
                )
            },
            hasElevators: hasElevators ?? false,
            toilets: toilets.map { StationToilets(label: $0.label, detail: $0.detail) }
        )
    }
}

struct RailMapDTO: Decodable {
    let routes: [NetworkRouteDTO]
    let stations: [NetworkStationDTO]

    func domain() throws -> TransitNetwork {
        TransitNetwork(
            routes: try routes.map { route in
                let badge = try RouteBadgeDTO(
                    id: route.id,
                    shortName: route.shortName,
                    mode: route.mode,
                    color: route.color,
                    textColor: route.textColor
                ).domain()
                return NetworkRoute(
                    badge: badge,
                    segments: route.segments.map {
                        NetworkSegment(id: $0.id, coordinates: $0.coordinates.map(\.domain))
                    }
                )
            },
            stations: stations.map { $0.domain() }
        )
    }
}

struct StationsAreaDTO: Decodable {
    let stations: [NetworkStationDTO]
    let routes: [RouteBadgeDTO]

    func domain() throws -> StationsArea {
        StationsArea(
            stations: stations.map { $0.domain() },
            routes: try routes.map { try $0.domain() }
        )
    }
}

struct BikeStationsAreaDTO: Decodable {
    struct Sources: Decodable {
        let velib: String
    }

    let bikeStations: [BikeStationDTO]
    let sources: Sources?

    var domain: BikeStationsArea {
        BikeStationsArea(
            stations: bikeStations.map { $0.domain },
            sourceAvailable: sources?.velib == "ok"
        )
    }
}

struct BikeStationDTO: Decodable {
    let id: String
    let stationCode: String?
    let name: String
    let coordinate: CoordinateDTO
    let capacity: Int
    let availability: BikeStationAvailability?

    var domain: BikeStation {
        BikeStation(
            id: id,
            stationCode: stationCode,
            name: name,
            coordinate: coordinate.domain,
            capacity: capacity,
            availability: availability
        )
    }
}

typealias SharedMobilityJSONPayload =
    Operations.network_period_sharedMobilityInArea.Output.Ok.Body.jsonPayload
typealias SharedMobilityItemPayload = SharedMobilityJSONPayload.itemsPayloadPayload
typealias SharedMobilityVehiclePayload = SharedMobilityItemPayload.Value1Payload
typealias SharedMobilityStationPayload = SharedMobilityItemPayload.Value2Payload
typealias SharedMobilitySourcesPayload = SharedMobilityJSONPayload.sourcesPayload

struct SharedMobilityAreaDTO: Decodable {
    let items: [SharedMobilityItemPayload]
    let sources: SharedMobilitySourcesPayload

    func domain() -> SharedMobilityArea {
        SharedMobilityArea(
            items: items.compactMap { $0.domain() },
            sources: sources.domain()
        )
    }
}

private extension SharedMobilityItemPayload {
    func domain() -> SharedMobilityItem? {
        if let vehicle = value1 { return vehicle.domain() }
        if let station = value2 { return station.domain() }
        return nil
    }
}

private extension SharedMobilityVehiclePayload {
    func domain() -> SharedMobilityItem? {
        guard
            kind == .vehicle,
            let provider = SharedMobilityProvider(rawValue: provider.rawValue),
            let mode = SharedMobilityMode(rawValue: mode.rawValue),
            availability == .available
        else { return nil }

        return .vehicle(SharedMobilityVehicle(
            id: id,
            provider: provider,
            mode: mode,
            vehicleType: vehicleType,
            availability: .available,
            coordinate: GeoCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ),
            batteryPercent: batteryPercent,
            rangeMeters: rangeMeters,
            lastReportedAt: lastReportedAt,
            restriction: restriction.flatMap { SharedMobilityRestriction(rawValue: $0.rawValue) },
            rentalURL: rentalUrl.flatMap(URL.init(string:)),
            operatorURL: operatorUrl.flatMap(URL.init(string:))
        ))
    }
}

private extension SharedMobilityStationPayload {
    func domain() -> SharedMobilityItem? {
        guard kind == .station, provider == .velib else { return nil }
        // The dock itself is a `BikeStation`, decoded exactly as the Vélib'
        // route decodes it; only what the generic layer adds is read here.
        return .station(SharedMobilityStation(
            station: BikeStation(
                id: id,
                stationCode: stationCode,
                name: name,
                coordinate: GeoCoordinate(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                ),
                capacity: capacity,
                availability: availability.map { value in
                    BikeStationAvailability(
                        mechanicalBikes: value.mechanicalBikes,
                        electricBikes: value.electricBikes,
                        docks: value.docks,
                        isInstalled: value.isInstalled,
                        isRenting: value.isRenting,
                        isReturning: value.isReturning,
                        lastReportedAt: value.lastReportedAt
                    )
                }
            ),
            operatorURL: operatorUrl.flatMap(URL.init(string:))
        ))
    }
}

private extension SharedMobilitySourcesPayload {
    func domain() -> [SharedMobilityProvider: SharedMobilitySourceStatus] {
        [
            .dott: sourceStatus(dott.status.rawValue, dott.sourceUpdatedAt, dott.expiresAt),
            .lime: sourceStatus(lime.status.rawValue, lime.sourceUpdatedAt, lime.expiresAt),
            .velib: sourceStatus(velib.status.rawValue, velib.sourceUpdatedAt, velib.expiresAt),
            .yego: sourceStatus(yego.status.rawValue, yego.sourceUpdatedAt, yego.expiresAt),
        ]
    }
}

/// The generator gives each provider its own nominal payload type, so four
/// identical `domain()` bodies is what writing this per type costs. The mapping
/// is one rule — an unknown state reads as unavailable — and it is written once
/// here, where a fifth operator adds a line rather than a fifth copy.
private func sourceStatus(
    _ status: String,
    _ sourceUpdatedAt: Date?,
    _ expiresAt: Date?
) -> SharedMobilitySourceStatus {
    SharedMobilitySourceStatus(
        state: SharedMobilitySourceState(rawValue: status) ?? .unavailable,
        sourceUpdatedAt: sourceUpdatedAt,
        expiresAt: expiresAt
    )
}
