import Foundation

enum SharedMobilityProvider: String, CaseIterable, Codable, Hashable, Sendable {
    case dott
    case lime
    case velib
    case yego

    var displayName: String {
        switch self {
        case .dott: "Dott"
        case .lime: "Lime"
        case .velib: "Vélib’ Métropole"
        case .yego: "YEGO"
        }
    }

    var logoAssetName: String {
        switch self {
        case .dott: "SharedMobilityDott"
        case .lime: "SharedMobilityLime"
        case .velib: "SharedMobilityVelib"
        case .yego: "SharedMobilityYego"
        }
    }

    /// Who actually operates a given mode in Île-de-France.
    ///
    /// This is network fact, not a display choice, so it lives beside the
    /// operators rather than in whichever view happens to ask. A map that keeps
    /// its own copy goes on claiming a layer is unavailable long after the API
    /// has added or dropped an operator, and nothing in Swift would break.
    static func providers(for mode: SharedMobilityMode) -> Set<SharedMobilityProvider> {
        switch mode {
        case .bicycle: [.dott, .lime]
        case .scooter: [.dott, .yego]
        }
    }
}

enum SharedMobilityMode: String, CaseIterable, Codable, Hashable, Sendable {
    case bicycle
    case scooter

    var displayName: String {
        switch self {
        case .bicycle: "Vélo"
        case .scooter: "Scooter"
        }
    }

    var systemImage: String {
        switch self {
        case .bicycle: "bicycle"
        case .scooter: "scooter"
        }
    }

    /// The shared-mobility mode stays grouped for filtering, while the map
    /// uses the more precise symbol for YEGO's motor scooters.
    func systemImage(for provider: SharedMobilityProvider) -> String {
        if self == .scooter, provider == .yego {
            return "moped"
        }
        return systemImage
    }
}

enum SharedMobilitySourceState: String, Codable, Hashable, Sendable {
    case ok
    case unavailable
}

struct SharedMobilitySourceStatus: Codable, Hashable, Sendable {
    let state: SharedMobilitySourceState
    let sourceUpdatedAt: Date?
    let expiresAt: Date?

    var isAvailable: Bool { isCurrent() }

    func isCurrent(at date: Date = .now) -> Bool {
        guard state == .ok else { return false }
        guard let expiresAt else { return true }
        return expiresAt > date
    }

    init(
        state: SharedMobilitySourceState,
        sourceUpdatedAt: Date? = nil,
        expiresAt: Date? = nil
    ) {
        self.state = state
        self.sourceUpdatedAt = sourceUpdatedAt
        self.expiresAt = expiresAt
    }
}

/// What the contract allows a listed vehicle to be. The decoder drops anything
/// else, so the map only ever holds vehicles someone can take — but the
/// vocabulary stays a type: a case added upstream then fails to compile here
/// instead of quietly rendering as "not available".
/// What a provider's geofencing feed forbids where the vehicle stands.
///
/// The API sends the fact; the sentence is built here, from the operator the
/// vehicle actually belongs to. That is what lets a second operator publish
/// zones without a second string being written server-side, and keeps the
/// French out of a parser that has no business holding it.
enum SharedMobilityRestriction: String, Codable, Hashable, Sendable {
    case noRide = "no-ride"

    func message(for provider: SharedMobilityProvider) -> String {
        switch self {
        case .noRide: "Zone de circulation restreinte selon \(provider.displayName)"
        }
    }
}

enum SharedMobilityAvailability: String, Codable, Hashable, Sendable {
    case available

    var displayName: String {
        switch self {
        case .available: "Disponible"
        }
    }
}

struct SharedMobilityVehicle: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let provider: SharedMobilityProvider
    let mode: SharedMobilityMode
    let vehicleType: String?
    let availability: SharedMobilityAvailability
    let coordinate: GeoCoordinate
    let batteryPercent: Double?
    let rangeMeters: Int?
    let lastReportedAt: Date?
    let restriction: SharedMobilityRestriction?
    let rentalURL: URL?
    let operatorURL: URL?

    var systemImage: String {
        mode.systemImage(for: provider)
    }

    var displayTypeName: String {
        if provider == .yego, mode == .scooter {
            return "Scooter électrique"
        }
        return vehicleType ?? mode.displayName
    }

    init(
        id: String,
        provider: SharedMobilityProvider,
        mode: SharedMobilityMode,
        vehicleType: String? = nil,
        availability: SharedMobilityAvailability = .available,
        coordinate: GeoCoordinate,
        batteryPercent: Double? = nil,
        rangeMeters: Int? = nil,
        lastReportedAt: Date? = nil,
        restriction: SharedMobilityRestriction? = nil,
        rentalURL: URL? = nil,
        operatorURL: URL? = nil
    ) {
        self.id = id
        self.provider = provider
        self.mode = mode
        self.vehicleType = vehicleType
        self.availability = availability
        self.coordinate = coordinate
        self.batteryPercent = batteryPercent
        self.rangeMeters = rangeMeters
        self.lastReportedAt = lastReportedAt
        self.restriction = restriction
        self.rentalURL = rentalURL
        self.operatorURL = operatorURL
    }
}

/// A dock as the generic layer sees it: the very same `BikeStation` the Vélib'
/// route returns, plus the two things only the generic layer knows about it.
///
/// Composed, never restated — the way `sharedMobilityStationSchema` extends
/// `bikeStationSchema` rather than repeating its fields. Every screen that
/// already knows how to draw a dock keeps taking a `BikeStation`, so the two
/// routes cannot end up wording the same station differently.
struct SharedMobilityStation: Codable, Hashable, Identifiable, Sendable {
    let station: BikeStation
    let provider: SharedMobilityProvider
    let operatorURL: URL?

    var id: String { station.id }

    init(
        station: BikeStation,
        provider: SharedMobilityProvider = .velib,
        operatorURL: URL? = nil
    ) {
        self.station = station
        self.provider = provider
        self.operatorURL = operatorURL
    }
}

enum SharedMobilityItem: Identifiable, Codable, Hashable, Sendable {
    case vehicle(SharedMobilityVehicle)
    case station(SharedMobilityStation)

    var id: String {
        switch self {
        case .vehicle(let vehicle): vehicle.id
        case .station(let dock): dock.id
        }
    }

    var provider: SharedMobilityProvider {
        switch self {
        case .vehicle(let vehicle): vehicle.provider
        case .station(let dock): dock.provider
        }
    }

    var mode: SharedMobilityMode? {
        switch self {
        case .vehicle(let vehicle): vehicle.mode
        case .station: nil
        }
    }

    var systemImage: String {
        switch self {
        case .vehicle(let vehicle): vehicle.systemImage
        case .station: "parkingsign"
        }
    }

    var coordinate: GeoCoordinate {
        switch self {
        case .vehicle(let vehicle): vehicle.coordinate
        case .station(let dock): dock.station.coordinate
        }
    }

    var name: String {
        switch self {
        case .vehicle(let vehicle):
            vehicle.displayTypeName
        case .station(let dock): dock.station.name
        }
    }

    var rentalURL: URL? {
        switch self {
        case .vehicle(let vehicle): vehicle.rentalURL
        case .station: nil
        }
    }

    var operatorURL: URL? {
        switch self {
        case .vehicle(let vehicle): vehicle.operatorURL
        case .station(let dock): dock.operatorURL
        }
    }

    var actionURL: URL? {
        switch self {
        case .vehicle: rentalURL ?? operatorURL
        case .station: operatorURL
        }
    }

    var lastReportedAt: Date? {
        switch self {
        case .vehicle(let vehicle): vehicle.lastReportedAt
        case .station(let dock): dock.station.availability?.lastReportedAt
        }
    }
}

struct SharedMobilityArea: Sendable, Hashable {
    let items: [SharedMobilityItem]
    let sources: [SharedMobilityProvider: SharedMobilitySourceStatus]

    init(
        items: [SharedMobilityItem] = [],
        sources: [SharedMobilityProvider: SharedMobilitySourceStatus] = [:]
    ) {
        self.items = items
        self.sources = sources
    }

    static let unavailable = SharedMobilityArea(
        sources: Dictionary(uniqueKeysWithValues: SharedMobilityProvider.allCases.map {
            ($0, SharedMobilitySourceStatus(state: .unavailable))
        })
    )

    func source(_ provider: SharedMobilityProvider) -> SharedMobilitySourceStatus {
        sources[provider] ?? SharedMobilitySourceStatus(state: .unavailable)
    }

    func currentItems(at date: Date = .now) -> [SharedMobilityItem] {
        items.filter { source($0.provider).isCurrent(at: date) }
    }
}

/// A map-only representation used when individual vehicles would overlap at
/// overview scale. It is never sent to the detail sheet: tapping it tightens
/// the camera until the actual vehicles can be selected.
struct SharedMobilityCluster: Sendable, Hashable, Identifiable {
    let id: String
    let coordinate: GeoCoordinate
    let provider: SharedMobilityProvider
    let mode: SharedMobilityMode
    let count: Int

    var systemImage: String {
        mode.systemImage(for: provider)
    }
}
