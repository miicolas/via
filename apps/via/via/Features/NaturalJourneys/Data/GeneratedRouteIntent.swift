import Foundation
import FoundationModels

@Generable(description: "Périmètre de la demande utilisateur")
enum GeneratedRouteScope {
    case journey
    case lineStatus
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

    @Guide(description: "Fragment exact de la saisie qui justifie le départ; chaîne vide si implicite")
    var evidence: String
}

@Generable(description: "Sens de l’heure demandée")
enum GeneratedRouteTimeMeaning {
    case departure
    case arrival
    case ambiguous
}

@Generable(description: "Jour formulé par l’utilisateur, sans calcul calendaire")
enum GeneratedDateReference {
    case implicitToday
    case today
    case tomorrow
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
    case calendarDate
    case relative
}

@Generable(description: "Précision horaire formulée par l’utilisateur")
enum GeneratedTimePrecision {
    case unspecified
    case exact
    case morning
    case afternoon
    case evening
}

@Generable(description: "Unité d’une durée relative")
enum GeneratedRelativeUnit {
    case minute
    case hour
    case day
}

@Generable(description: "Composants temporels extraits tels quels, sans date ISO 8601")
struct GeneratedRouteDateTime {
    @Guide(description: "implicitToday si aucun jour n’est cité; relative pour une durée; sinon le jour cité")
    var reference: GeneratedDateReference

    @Guide(description: "Année citée, sinon année neutre 2000", .range(2000 ... 2100))
    var year: Int

    @Guide(description: "Vrai seulement si l’année est explicitement écrite")
    var yearWasExplicit: Bool

    @Guide(description: "Mois cité pour calendarDate, sinon valeur neutre 1", .range(1 ... 12))
    var month: Int

    @Guide(description: "Jour cité pour calendarDate, sinon valeur neutre 1", .range(1 ... 31))
    var day: Int

    @Guide(description: "exact pour une heure chiffrée; morning, afternoon ou evening pour une partie de journée")
    var timePrecision: GeneratedTimePrecision

    @Guide(description: "Heure citée quand timePrecision vaut exact, sinon 0", .range(0 ... 23))
    var hour: Int

    @Guide(description: "Minutes citées quand timePrecision vaut exact, sinon 0", .range(0 ... 59))
    var minute: Int

    @Guide(description: "Nombre cité quand reference vaut relative, sinon 0", .range(0 ... 10080))
    var relativeAmount: Int

    @Guide(description: "Unité citée quand reference vaut relative, sinon minute")
    var relativeUnit: GeneratedRelativeUnit
}

@Generable(description: "Contrainte temporelle complète et son sens")
struct GeneratedRouteTimeConstraint {
    var dateTime: GeneratedRouteDateTime
    var meaning: GeneratedRouteTimeMeaning

    @Guide(description: "Fragment exact qui justifie la date ou l’heure; chaîne vide si implicite")
    var evidence: String
}

@Generable(description: "Mode de transport en commun francilien")
enum GeneratedTransitMode {
    case metro
    case rer
    case transilien
    case tram
    case bus
}

@Generable(description: "Type de consultation de l’état du réseau")
enum GeneratedLineStatusKind {
    case specific
    case networkOverview
    case disruptions
}

@Generable(description: "Mode explicitement cité dans une question de trafic")
enum GeneratedLineStatusMode {
    case any
    case metro
    case rer
    case transilien
    case tram
    case bus
}

@Generable(description: "Question structurée sur l’état réel d’une ligne, sans réponse de trafic")
struct GeneratedLineStatusIntent {
    var kind: GeneratedLineStatusKind

    @Guide(description: "Code visible exact de la ligne, par exemple 4, A, T3a, N ou 38; vide pour une vue réseau")
    var code: String

    @Guide(description: "Mode cité explicitement, sinon any")
    var mode: GeneratedLineStatusMode

    @Guide(description: "Fragment exact de la saisie qui justifie la question de trafic")
    var evidence: String
}

@Generable(description: "Intention de trajet francilien structurée et sans géocodage")
struct GeneratedRouteIntent {
    var scope: GeneratedRouteScope
    var origin: GeneratedRouteOrigin

    @Guide(description: "Vrai seulement si l’utilisateur a explicitement formulé une origine, y compris sa position actuelle")
    var originWasExplicit: Bool

    @Guide(description: "Destination formulée par l’utilisateur, ou absence si elle manque")
    var destinationQuery: String?

    @Guide(description: "Fragment exact de la saisie qui justifie la destination; chaîne vide si absente")
    var destinationEvidence: String

    @Guide(description: "Vrai uniquement pour « le dernier train/métro/RER/bus/tram » de la journée; jamais pour une heure citée")
    var lastServiceOfDay: Bool

    @Guide(description: "Contrainte principale; utilise implicitToday et unspecified si aucune date ni heure n’est formulée")
    var timeConstraint: GeneratedRouteTimeConstraint

    @Guide(description: "Seconde contrainte complète uniquement si départ et arrivée ont chacun une heure")
    var alternateTimeConstraint: GeneratedRouteTimeConstraint?

    @Guide(description: "Modes obligatoires", .maximumCount(3))
    var requiredModes: [GeneratedTransitMode]

    @Guide(description: "Modes exclus", .maximumCount(3))
    var excludedModes: [GeneratedTransitMode]

    @Guide(description: "Modes préférés mais non obligatoires", .maximumCount(3))
    var preferredModes: [GeneratedTransitMode]

    @Guide(description: "Contraintes comprises mais non prises en charge; marche maximale, accessibilité, ligne précise, coût ou confort", .maximumCount(3))
    var unsupportedConstraints: [String]

    @Guide(description: "Fragment significatif non expliqué, ou chaîne vide si toute la demande est couverte")
    var unexplainedText: String

    @Guide(description: "Obligatoire seulement lorsque scope vaut lineStatus; ne contient jamais la réponse temps réel")
    var lineStatus: GeneratedLineStatusIntent?

    func domain(
        now: Date,
        phrase: String,
        originAnchor: NaturalIntentModelAnchor? = nil,
        destinationAnchor: NaturalIntentModelAnchor? = nil,
    ) throws(NaturalIntentParsingError) -> RouteIntent {
        let mappedOrigin: RouteOriginIntent
        switch origin.kind {
        case .currentLocation:
            if !origin.evidence.isEmpty,
               !Self.isEvidence(origin.evidence, groundedIn: phrase)
            {
                throw .invalidResponse
            }
            guard originWasExplicit == !origin.evidence
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw .invalidResponse }
            if originWasExplicit {
                let evidence = OnDevicePlaceResolver.normalize(origin.evidence)
                guard [
                    "ma position", "position actuelle", "ici", "d ici",
                    "my location", "current location", "here",
                ].contains(evidence) else { throw .invalidResponse }
            }
            mappedOrigin = .currentLocation
        case .place:
            guard originWasExplicit || originAnchor != nil else { throw .invalidResponse }
            guard let query = Self.validPlace(origin.query) else { throw .invalidResponse }
            guard originAnchor != nil
                    || Self.isPlace(query, groundedBy: origin.evidence, in: phrase)
            else {
                throw .invalidResponse
            }
            mappedOrigin = .place(query: query)
        }

        let destination: String?
        if let destinationQuery {
            guard let validDestination = Self.validPlace(destinationQuery) else {
                throw .invalidResponse
            }
            guard destinationAnchor != nil
                    || Self.isPlace(validDestination, groundedBy: destinationEvidence, in: phrase)
            else {
                throw .invalidResponse
            }
            destination = validDestination
        } else {
            guard destinationEvidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw .invalidResponse
            }
            destination = nil
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

        let mappedLineStatus = try Self.validLineStatus(
            lineStatus,
            scope: scope,
            phrase: phrase,
            originWasExplicit: originWasExplicit,
            hasDestination: destination != nil,
            lastServiceOfDay: lastServiceOfDay,
            hasJourneyModes: !requiredModes.isEmpty
                || !excludedModes.isEmpty
                || !preferredModes.isEmpty,
            hasUnsupportedConstraints: !constraints.isEmpty,
            timeConstraint: timeConstraint,
            hasAlternateTimeConstraint: alternateTimeConstraint != nil,
        )

        let timeMeaning: RouteIntent.TimeMeaning = switch timeConstraint.meaning {
        case .departure: .departure
        case .arrival: .arrival
        case .ambiguous: .ambiguous
        }

        let resolvedTime: ResolvedNaturalDateTime
        let alternateTimeConstraint: RouteTimeConstraint?
        if scope != .journey {
            resolvedTime = ResolvedNaturalDateTime(
                date: now,
                dateWasExplicit: false,
                timeWasExplicit: false
            )
            alternateTimeConstraint = nil
        } else {
            do {
                resolvedTime = try NaturalDateTimeResolver.resolve(
                    timeConstraint.dateTime.domain.validatingExplicitTime(
                        in: timeConstraint.evidence
                    ),
                    now: now
                )
            } catch {
                throw .invalidResponse
            }

            if let alternate = self.alternateTimeConstraint {
                guard Self.isEvidence(alternate.evidence, groundedIn: phrase) else {
                    throw .invalidResponse
                }
                let resolvedAlternate: ResolvedNaturalDateTime
                do {
                    resolvedAlternate = try NaturalDateTimeResolver.resolve(
                        alternate.dateTime.domain.validatingExplicitTime(
                            in: alternate.evidence
                        ),
                        now: now
                    )
                } catch {
                    throw .invalidResponse
                }
                let domainMeaning: JourneyDatetimeRepresents
                switch alternate.meaning {
                case .departure: domainMeaning = .departure
                case .arrival: domainMeaning = .arrival
                case .ambiguous: throw .invalidResponse
                }
                alternateTimeConstraint = RouteTimeConstraint(
                    requestedAt: resolvedAlternate.date,
                    meaning: domainMeaning
                )
            } else {
                alternateTimeConstraint = nil
            }
        }

        let domainScope: RouteIntent.Scope = switch scope {
        case .journey: .journey
        case .lineStatus: .lineStatus
        case .unsupported: .unsupported
        }
        return RouteIntent(
            scope: domainScope,
            origin: mappedOrigin,
            destinationQuery: destination,
            requestedAt: resolvedTime.date,
            datetimeRepresents: timeMeaning,
            timeAnchor: lastServiceOfDay ? .lastOfDay : nil,
            requiredModes: Set(requiredModes.map(\.domain)),
            excludedModes: Set(excludedModes.map(\.domain)),
            preferredModes: Set(preferredModes.map(\.domain)),
            unsupportedConstraints: constraints,
            dateWasExplicit: resolvedTime.dateWasExplicit,
            timeWasExplicit: resolvedTime.timeWasExplicit,
            alternateTimeConstraint: alternateTimeConstraint,
            originWasExplicit: originAnchor == nil ? originWasExplicit : true,
            lineStatus: mappedLineStatus,
        )
    }

    private static func validLineStatus(
        _ line: GeneratedLineStatusIntent?,
        scope: GeneratedRouteScope,
        phrase: String,
        originWasExplicit: Bool,
        hasDestination: Bool,
        lastServiceOfDay: Bool,
        hasJourneyModes: Bool,
        hasUnsupportedConstraints: Bool,
        timeConstraint: GeneratedRouteTimeConstraint,
        hasAlternateTimeConstraint: Bool,
    ) throws(NaturalIntentParsingError) -> NaturalLineStatusIntent? {
        guard scope == .lineStatus else {
            guard line == nil else { throw .invalidResponse }
            return nil
        }
        guard let line,
              !originWasExplicit,
              !hasDestination,
              !lastServiceOfDay,
              !hasJourneyModes,
              !hasUnsupportedConstraints,
              timeConstraint.dateTime.reference == .implicitToday,
              !timeConstraint.dateTime.yearWasExplicit,
              timeConstraint.dateTime.timePrecision == .unspecified,
              timeConstraint.dateTime.relativeAmount == 0,
              timeConstraint.meaning == .departure,
              timeConstraint.evidence.isEmpty,
              !hasAlternateTimeConstraint,
              isEvidence(line.evidence, groundedIn: phrase)
        else { throw .invalidResponse }

        let kind: NaturalLineStatusIntent.Kind = switch line.kind {
        case .specific: .specific
        case .networkOverview: .networkOverview
        case .disruptions: .disruptions
        }
        let mode: TransitMode? = switch line.mode {
        case .any: nil
        case .metro: .metro
        case .rer: .rer
        case .transilien: .transilien
        case .tram: .tram
        case .bus: .bus
        }
        if let mode {
            let evidence = OnDevicePlaceResolver.normalize(line.evidence)
            guard evidence.contains(mode.rawValue)
                    || (mode == .transilien && evidence.contains("train"))
            else { throw .invalidResponse }
        }

        let code = line.code.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .specific:
            let escaped = NSRegularExpression.escapedPattern(
                for: OnDevicePlaceResolver.normalize(code)
            )
            let evidence = OnDevicePlaceResolver.normalize(line.evidence)
            guard !code.isEmpty,
                  code.count <= 12,
                  let expression = try? NSRegularExpression(
                    pattern: "(^|[^a-z0-9])\(escaped)([^a-z0-9]|$)",
                    options: [.caseInsensitive],
                  ),
                  expression.firstMatch(
                    in: evidence,
                    range: NSRange(evidence.startIndex..., in: evidence),
                  ) != nil
            else { throw .invalidResponse }
        case .networkOverview, .disruptions:
            guard code.isEmpty else { throw .invalidResponse }
        }
        return NaturalLineStatusIntent(
            kind: kind,
            code: code,
            mode: mode,
            evidence: line.evidence,
        )
    }

    private static func validPlace(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.count > 160 ? nil : trimmed
    }

    func proposal(
        for request: NaturalIntentModelRequest
    ) throws(NaturalIntentParsingError) -> NaturalIntentProposal {
        let intent = try domain(
            now: request.now,
            phrase: request.phrase,
            originAnchor: request.originAnchor,
            destinationAnchor: request.destinationAnchor,
        )
        let residue = unexplainedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard residue.count <= 200,
              residue.isEmpty || Self.isEvidence(residue, groundedIn: request.phrase)
        else {
            throw .invalidResponse
        }
        return NaturalIntentProposal(
            intent: intent,
            originEvidence: origin.evidence.nilIfEmpty,
            destinationEvidence: destinationEvidence.nilIfEmpty,
            timeEvidence: timeConstraint.evidence.nilIfEmpty,
            unexplainedText: residue.nilIfEmpty,
        )
    }

    private static func isPlace(_ query: String, groundedBy evidence: String, in phrase: String) -> Bool {
        guard isEvidence(evidence, groundedIn: phrase) else { return false }
        let normalizedQuery = OnDevicePlaceResolver.normalize(query)
        let normalizedEvidence = OnDevicePlaceResolver.normalize(evidence)
        return normalizedEvidence.contains(normalizedQuery)
    }

    private static func isEvidence(_ evidence: String, groundedIn phrase: String) -> Bool {
        let trimmed = evidence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 160 else { return false }
        return phrase.range(
            of: trimmed,
            options: [.caseInsensitive, .diacriticInsensitive],
        ) != nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension GeneratedRouteDateTime {
    var domain: NaturalDateTimeParts {
        NaturalDateTimeParts(
            reference: reference.domain,
            year: year,
            yearWasExplicit: yearWasExplicit,
            month: month,
            day: day,
            timePrecision: timePrecision.domain,
            hour: hour,
            minute: minute,
            relativeAmount: relativeAmount,
            relativeUnit: relativeUnit.domain
        )
    }
}

private extension GeneratedDateReference {
    var domain: NaturalDateReference {
        switch self {
        case .implicitToday: .implicitToday
        case .today: .today
        case .tomorrow: .tomorrow
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        case .sunday: .sunday
        case .calendarDate: .calendarDate
        case .relative: .relative
        }
    }
}

private extension GeneratedTimePrecision {
    var domain: NaturalTimePrecision {
        switch self {
        case .unspecified: .unspecified
        case .exact: .exact
        case .morning: .morning
        case .afternoon: .afternoon
        case .evening: .evening
        }
    }
}

private extension GeneratedRelativeUnit {
    var domain: NaturalRelativeUnit {
        switch self {
        case .minute: .minute
        case .hour: .hour
        case .day: .day
        }
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
