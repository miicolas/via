import Foundation
import FoundationModels

actor FoundationModelsChatContext {
    struct RegisteredPlace: Sendable {
        let reference: String
        let result: SearchResult
    }

    private let location: GeoCoordinate?
    private var places: [String: SearchResult] = [:]
    private var nextReference = 1
    private var publishedItinerary: ChatItinerary?

    init(location: GeoCoordinate?) {
        self.location = location
    }

    func register(_ results: [SearchResult]) -> [RegisteredPlace] {
        results.map { result in
            let reference = "lieu_\(nextReference)"
            nextReference += 1
            places[reference] = result
            return RegisteredPlace(reference: reference, result: result)
        }
    }

    func place(for reference: String) -> SearchResult? {
        places[reference]
    }

    func currentLocation() -> GeoCoordinate? {
        location
    }

    func publish(_ itinerary: ChatItinerary) {
        publishedItinerary = itinerary
    }

    func itinerary() -> ChatItinerary? {
        publishedItinerary
    }
}

@Generable(description: "Paramètres de recherche d’un lieu en Île-de-France")
struct FoundationModelsPlaceSearchArguments {
    @Guide(description: "Nom du lieu, de la station, de la commune ou adresse formulé par l’utilisateur")
    var query: String
}

struct FoundationModelsPlaceSearchTool: Tool {
    let search: @Sendable (String, GeoCoordinate?) async throws -> SearchResponse
    let context: FoundationModelsChatContext

    var name: String { "chercher_lieu" }
    var description: String {
        "Recherche un lieu francilien fiable. Appelle cet outil pour chaque origine et destination avant de calculer un trajet."
    }

    func call(arguments: FoundationModelsPlaceSearchArguments) async throws -> String {
        let response = try await search(arguments.query, await context.currentLocation())
        let registered = await context.register(Array(response.results.prefix(5)))

        guard !registered.isEmpty else {
            return response.addressSource == .unavailable
                ? "statut: indisponible; la recherche d’adresses est temporairement indisponible"
                : "statut: aucun_resultat"
        }

        let candidates = registered.map { place in
            let kind: String
            let contextLabel: String
            switch place.result {
            case .station:
                kind = "station"
                contextLabel = ""
            case .address(let address):
                kind = "adresse"
                contextLabel = address.context.isEmpty ? "" : "; contexte: \(address.context)"
            }
            return "référence: \(place.reference); type: \(kind); nom: \(place.result.name)\(contextLabel)"
        }

        return "statut: résultats\n" + candidates.joined(separator: "\n")
    }
}

@Generable(description: "Sens temporel d’un calcul de trajet")
enum FoundationModelsJourneyTimeKind {
    case departure
    case arrival
}

@Generable(description: "Paramètres d’un calcul de trajet Via")
struct FoundationModelsJourneyArguments {
    @Guide(description: "Référence exacte de destination renvoyée par chercher_lieu")
    var destinationReference: String

    @Guide(description: "Référence d’origine renvoyée par chercher_lieu, ou absence pour utiliser la position actuelle")
    var originReference: String?

    @Guide(description: "Date et heure ISO 8601 avec décalage, uniquement si l’utilisateur en a demandé une")
    var requestedAtISO8601: String?

    @Guide(description: "Indique si l’heure demandée est celle du départ ou de l’arrivée")
    var datetimeRepresents: FoundationModelsJourneyTimeKind?
}

struct FoundationModelsJourneyTool: Tool {
    let plan: @Sendable (JourneyRequest) async throws -> JourneyResult
    let context: FoundationModelsChatContext

    var name: String { "calculer_itineraires" }
    var description: String {
        "Calcule des trajets réels à partir de références obtenues avec chercher_lieu. C’est la seule source autorisée pour les horaires, lignes et durées."
    }

    func call(arguments: FoundationModelsJourneyArguments) async throws -> String {
        guard let destinationResult = await context.place(for: arguments.destinationReference) else {
            return "statut: référence_destination_invalide; appelle chercher_lieu avant de réessayer"
        }

        let origin: GeoCoordinate?
        if let originReference = arguments.originReference {
            origin = await context.place(for: originReference)?.coordinate
        } else {
            origin = await context.currentLocation()
        }
        guard let origin else {
            return "statut: origine_manquante; demande le point de départ à l’utilisateur"
        }

        let requestedAt: Date?
        if let requestedAtISO8601 = arguments.requestedAtISO8601 {
            guard let parsedDate = ISO8601.parse(requestedAtISO8601) else {
                return "statut: heure_invalide; demande une date ou une heure plus précise"
            }
            requestedAt = parsedDate
        } else {
            requestedAt = nil
        }

        let datetimeRepresents: JourneyDatetimeRepresents? = switch arguments.datetimeRepresents {
        case .departure: .departure
        case .arrival: .arrival
        case nil: nil
        }
        let destination = Self.destination(from: destinationResult)
        var request = JourneyRequest(origin: origin, destination: destination)
        request.limit = 3
        request.requestedAt = requestedAt
        request.datetimeRepresents = datetimeRepresents

        let result = try await plan(request)
        await context.publish(ChatItinerary(
            destination: destination,
            requestedAt: requestedAt,
            datetimeRepresents: datetimeRepresents,
            result: result
        ))
        return Self.digest(result)
    }

    private static func destination(from result: SearchResult) -> JourneyDestination {
        switch result {
        case .station(let station):
            .station(id: station.id, name: station.name, coordinate: station.coordinate)
        case .address(let address):
            .address(
                id: address.id,
                name: address.name,
                context: address.context,
                coordinate: address.coordinate
            )
        }
    }

    private static func digest(_ result: JourneyResult) -> String {
        guard result.status == .ready, !result.journeys.isEmpty else {
            return "statut: \(result.status.rawValue)"
        }

        let journeys = result.journeys.prefix(3).enumerated().map { index, journey in
            let transitSections = journey.sections.compactMap { section -> String? in
                guard section.kind == .transit, let route = section.route else { return nil }
                return "\(route.mode.rawValue) \(route.shortName) de \(section.from.name) vers \(section.to.name)"
            }
            let warnings = journey.warnings.isEmpty
                ? "aucun"
                : journey.warnings.joined(separator: " | ")
            return """
            option \(index + 1): départ \(ISO8601.string(journey.departureAt)); arrivée \(ISO8601.string(journey.arrivalAt)); durée \(journey.durationSeconds / 60) min; correspondances \(journey.transferCount); marche \(journey.walkingDurationSeconds / 60) min; sections \(transitSections.joined(separator: " puis ")); alertes \(warnings)
            """
        }
        return "statut: ready\n" + journeys.joined(separator: "\n")
    }
}
