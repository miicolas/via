import Foundation

enum ReportSection: String, Codable, Sendable, Hashable, CaseIterable {
    case station
    case train

    var title: String {
        switch self {
        case .station:
            "À la station"
        case .train:
            "Dans mon train"
        }
    }
}

enum ReportCategory: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case pickpocket
    case crowding
    case restroomsClosed
    case ticketMachineUnavailable
    case elevatorsUnavailable
    case stopMoved
    case stopNotServed
    case airConditioningPresent

    var id: String { rawValue }

    var section: ReportSection {
        switch self {
        case .airConditioningPresent:
            .train
        case .pickpocket,
             .crowding,
             .restroomsClosed,
             .ticketMachineUnavailable,
             .elevatorsUnavailable,
             .stopMoved,
             .stopNotServed:
            .station
        }
    }

    var title: String {
        switch self {
        case .pickpocket:
            "Pickpocket"
        case .crowding:
            "Forte affluence"
        case .restroomsClosed:
            "WC fermés"
        case .ticketMachineUnavailable:
            "Distributeur indisponible"
        case .elevatorsUnavailable:
            "Ascenseurs indisponibles"
        case .stopMoved:
            "Arrêt déplacé ici"
        case .stopNotServed:
            "Arrêt non desservi"
        case .airConditioningPresent:
            "Climatisation présente"
        }
    }

    var systemImage: String {
        switch self {
        case .pickpocket:
            "figure.run"
        case .crowding:
            "person.3.fill"
        case .restroomsClosed:
            "figure.dress.line.vertical.figure"
        case .ticketMachineUnavailable:
            "creditcard.fill"
        case .elevatorsUnavailable:
            "arrow.up.arrow.down.square.fill"
        case .stopMoved:
            "arrow.right.circle.fill"
        case .stopNotServed:
            "minus.circle.fill"
        case .airConditioningPresent:
            "snowflake"
        }
    }
}

/// Context attached to an observation. The optional transit identifiers are
/// deliberately ready for the future live-journey flow without being required
/// by the first report screen.
struct ReportContext: Codable, Sendable, Hashable {
    let coordinate: GeoCoordinate?
    let stationID: StationID?
    let routeID: RouteID?
    let journeyID: JourneyID?
    let vehicleID: String?

    init(
        coordinate: GeoCoordinate? = nil,
        stationID: StationID? = nil,
        routeID: RouteID? = nil,
        journeyID: JourneyID? = nil,
        vehicleID: String? = nil
    ) {
        self.coordinate = coordinate
        self.stationID = stationID
        self.routeID = routeID
        self.journeyID = journeyID
        self.vehicleID = vehicleID
    }
}

struct ReportSubmission: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let category: ReportCategory
    let context: ReportContext
    let observedAt: Date

    init(
        id: UUID = UUID(),
        category: ReportCategory,
        context: ReportContext,
        observedAt: Date
    ) {
        self.id = id
        self.category = category
        self.context = context
        self.observedAt = observedAt
    }
}
