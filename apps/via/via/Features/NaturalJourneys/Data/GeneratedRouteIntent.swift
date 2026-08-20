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

    @Guide(description: "Vrai seulement si l’utilisateur a explicitement formulé une origine, y compris sa position actuelle")
    var originWasExplicit: Bool

    @Guide(description: "Destination formulée par l’utilisateur, ou absence si elle manque")
    var destinationQuery: String?

    @Guide(description: "Date et heure ISO 8601 avec décalage Europe/Paris, ou absence si inconnue")
    var requestedAt: String?

    @Guide(description: "Vrai seulement si l’utilisateur a formulé un jour ou une date")
    var dateWasExplicit: Bool

    @Guide(description: "Vrai seulement si l’utilisateur a formulé une heure ou une partie de journée")
    var timeWasExplicit: Bool

    var datetimeRepresents: GeneratedRouteTimeMeaning

    @Guide(description: "Seconde date et heure ISO 8601 uniquement si la phrase contient à la fois une contrainte de départ et d’arrivée")
    var alternateRequestedAt: String?

    @Guide(description: "Sens de la seconde heure, ou absence si alternateRequestedAt est absent")
    var alternateDatetimeRepresents: GeneratedRouteTimeMeaning?

    @Guide(description: "Modes obligatoires, au plus trois")
    var requiredModes: [GeneratedTransitMode]

    @Guide(description: "Modes exclus, au plus trois")
    var excludedModes: [GeneratedTransitMode]

    @Guide(description: "Modes préférés mais non obligatoires, au plus trois")
    var preferredModes: [GeneratedTransitMode]

    @Guide(description: "Contraintes de trajet comprises mais non prises en charge par Via, au plus trois; par exemple marche maximale, accessibilité, ligne précise, coût ou confort")
    var unsupportedConstraints: [String]

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

        guard requiredModes.count <= 3,
              excludedModes.count <= 3,
              preferredModes.count <= 3,
              unsupportedConstraints.count <= 3
        else {
            throw .invalidResponse
        }

        let constraints = unsupportedConstraints.compactMap { value -> String? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed.count > 160 ? nil : trimmed
        }
        guard constraints.count == unsupportedConstraints.count else { throw .invalidResponse }

        let timeMeaning: RouteIntent.TimeMeaning = switch datetimeRepresents {
        case .departure: .departure
        case .arrival: .arrival
        case .ambiguous: .ambiguous
        }

        let alternateTimeConstraint: RouteTimeConstraint?
        switch (alternateRequestedAt, alternateDatetimeRepresents) {
        case (nil, nil):
            alternateTimeConstraint = nil
        case let (.some(value), .some(meaning)):
            guard let date = ISO8601.parse(value) else { throw .invalidResponse }
            let domainMeaning: JourneyDatetimeRepresents
            switch meaning {
            case .departure: domainMeaning = .departure
            case .arrival: domainMeaning = .arrival
            case .ambiguous: throw .invalidResponse
            }
            alternateTimeConstraint = RouteTimeConstraint(
                requestedAt: date,
                meaning: domainMeaning
            )
        default:
            throw .invalidResponse
        }

        return RouteIntent(
            scope: scope == .journey ? .journey : .unsupported,
            origin: mappedOrigin,
            destinationQuery: destination,
            requestedAt: date,
            datetimeRepresents: timeMeaning,
            requiredModes: Set(requiredModes.map(\.domain)),
            excludedModes: Set(excludedModes.map(\.domain)),
            preferredModes: Set(preferredModes.map(\.domain)),
            unsupportedConstraints: constraints,
            dateWasExplicit: dateWasExplicit,
            timeWasExplicit: timeWasExplicit,
            alternateTimeConstraint: alternateTimeConstraint,
            originWasExplicit: originWasExplicit
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
