import Foundation
import FoundationModels

@Generable(description: "Périmètre de la demande utilisateur")
enum GeneratedRouteScope {
    case journey
    case unsupported
}

@Generable(description: "Type de point de départ")
enum GeneratedRouteOriginKind {
    case currentLocation
    case place
}

@Generable(description: "Point de départ demandé")
struct GeneratedRouteOrigin {
    @Guide(description: "Position actuelle si aucun départ n’est indiqué, sinon lieu explicite")
    var kind: GeneratedRouteOriginKind

    @Guide(description: "Libellé exact du lieu de départ, uniquement lorsque kind vaut place")
    var query: String?
}

@Generable(description: "Sens de l’heure demandée")
enum GeneratedRouteTimeMeaning {
    case departure
    case arrival
    case ambiguous
}

@Generable(description: "Mode de transport en commun francilien")
enum GeneratedTransitMode {
    case metro
    case rer
    case transilien
    case tram
    case bus
}

@Generable(description: "Intention de trajet francilien structurée et sans géocodage")
struct GeneratedRouteIntent {
    var scope: GeneratedRouteScope
    var origin: GeneratedRouteOrigin

    @Guide(description: "Destination formulée par l’utilisateur, ou absence si elle manque")
    var destinationQuery: String?

    @Guide(description: "Date et heure ISO 8601 avec décalage Europe/Paris, ou absence si inconnue")
    var requestedAt: String?

    var datetimeRepresents: GeneratedRouteTimeMeaning

    @Guide(description: "Modes obligatoires, au plus trois")
    var requiredModes: [GeneratedTransitMode]

    @Guide(description: "Modes exclus, au plus trois")
    var excludedModes: [GeneratedTransitMode]

    @Guide(description: "Modes préférés mais non obligatoires, au plus trois")
    var preferredModes: [GeneratedTransitMode]

    func domain(now: Date) throws(NaturalIntentParsingError) -> RouteIntent {
        _ = now
        let mappedOrigin: RouteOriginIntent
        switch origin.kind {
        case .currentLocation:
            mappedOrigin = .currentLocation
        case .place:
            guard let query = Self.validPlace(origin.query) else { throw .invalidResponse }
            mappedOrigin = .place(query: query)
        }

        let destination: String?
        if let destinationQuery {
            guard let validDestination = Self.validPlace(destinationQuery) else {
                throw .invalidResponse
            }
            destination = validDestination
        } else {
            destination = nil
        }

        let date: Date?
        if let requestedAt {
            guard let parsed = ISO8601.parse(requestedAt) else { throw .invalidResponse }
            date = parsed
        } else {
            date = nil
        }

        guard requiredModes.count <= 3, excludedModes.count <= 3, preferredModes.count <= 3 else {
            throw .invalidResponse
        }

        let timeMeaning: RouteIntent.TimeMeaning = switch datetimeRepresents {
        case .departure: .departure
        case .arrival: .arrival
        case .ambiguous: .ambiguous
        }

        return RouteIntent(
            scope: scope == .journey ? .journey : .unsupported,
            origin: mappedOrigin,
            destinationQuery: destination,
            requestedAt: date,
            datetimeRepresents: timeMeaning,
            requiredModes: Set(requiredModes.map(\.domain)),
            excludedModes: Set(excludedModes.map(\.domain)),
            preferredModes: Set(preferredModes.map(\.domain))
        )
    }

    private static func validPlace(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.count > 160 ? nil : trimmed
    }
}

private extension GeneratedTransitMode {
    var domain: TransitMode {
        switch self {
        case .metro: .metro
        case .rer: .rer
        case .transilien: .transilien
        case .tram: .tram
        case .bus: .bus
        }
    }
}
