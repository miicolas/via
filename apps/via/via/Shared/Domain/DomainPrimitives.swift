import Foundation

struct StationID: RawRepresentable, Codable, Sendable, Hashable {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
}

struct RouteID: RawRepresentable, Codable, Sendable, Hashable {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
}

struct JourneyID: RawRepresentable, Codable, Sendable, Hashable {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
}

struct GeoCoordinate: Codable, Sendable, Hashable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = min(90, max(-90, latitude))
        self.longitude = min(180, max(-180, longitude))
    }

    var roundedForSearch: GeoCoordinate {
        GeoCoordinate(
            latitude: (latitude * 10_000).rounded() / 10_000,
            longitude: (longitude * 10_000).rounded() / 10_000
        )
    }
}

struct GeoBounds: Codable, Sendable, Hashable {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double

    var isValid: Bool {
        minLatitude < maxLatitude && minLongitude < maxLongitude
    }
}

enum TransitMode: String, Codable, CaseIterable, Sendable, Hashable {
    case metro
    case rer
    case bus
}

struct RouteBadge: Codable, Sendable, Hashable, Identifiable {
    let id: RouteID
    let shortName: String
    let mode: TransitMode
    let colorHex: String
    let textColorHex: String
}

enum ViaError: Error, Sendable, Equatable {
    case invalidConfiguration(String)
    case invalidRequest(String)
    case transport
    case decoding
    case unauthorized
    case rateLimited
    case unavailable
    case server(statusCode: Int)
}

enum Loadable<Value: Sendable & Equatable>: Sendable, Equatable {
    case idle
    case loading(previous: Value?)
    case loaded(Value)
    case failed(ViaError, previous: Value?)
}

extension Loadable {
    var value: Value? {
        switch self {
        case .loaded(let value): value
        case .loading(let previous), .failed(_, let previous): previous
        case .idle: nil
        }
    }
}

extension Error {
    var via: ViaError {
        self as? ViaError ?? (self is DecodingError ? .decoding : .transport)
    }
}
