import Foundation

struct OnDeviceNaturalJourneyService: NaturalJourneyRepository {
    private static let unsupportedMessage = "Via peut t’aider à préparer un trajet en Île-de-France"
    private static let examples = [
        "Depuis Châtelet, je veux être à Gare du Nord à 10 h",
        "12 rue de Rivoli avant 9 h",
    ]

    private let parser: any NaturalIntentParsing
    private let places: OnDevicePlaceResolver
    private let journeys: any JourneyRepository
    private let now: @Sendable () -> Date
    private let metrics: any NaturalJourneyMetricsRecording
    private let metricsNow: @Sendable () -> Date

    init(
        parser: any NaturalIntentParsing,
        places: OnDevicePlaceResolver,
        journeys: any JourneyRepository,
        now: @escaping @Sendable () -> Date = { .now },
        metrics: any NaturalJourneyMetricsRecording = NoOpNaturalJourneyMetrics(),
        metricsNow: @escaping @Sendable () -> Date = { .now },
    ) {
        self.parser = parser
        self.places = places
        self.journeys = journeys
        self.now = now
        self.metrics = metrics
        self.metricsNow = metricsNow
    }

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        let currentTime = now()
        var draft: NaturalJourneyDraft
        let currentLocation: GeoCoordinate?

        switch request {
        case let .submit(query, location):
            let interpretationStartedAt = metricsNow()
            do {
                let parsed = try await parser.parseIntent(query, now: currentTime)
                recordInterpretation(startedAt: interpretationStartedAt)
                let intent = Self.normalizedTime(in: parsed, now: currentTime)
                draft = NaturalJourneyDraft(intent: intent, origin: nil, destination: nil)
            } catch NaturalIntentParsingError.cancelled {
                throw CancellationError()
            } catch {
                recordInterpretation(startedAt: interpretationStartedAt)
                throw error
            }
            currentLocation = location
        case let .resolve(
            submittedDraft,
            location,
            submittedOrigin,
            submittedDestination,
            submittedRequestedAt,
            submittedTime,
        ):
            let origin = try await verify(
                submittedOrigin ?? submittedDraft.origin,
                near: location,
            )
            try Task.checkCancellation()
            let destination = try await verify(
                submittedDestination ?? submittedDraft.destination,
                near: location,
            )
            let intent: RouteIntent = if let submittedTime {
                submittedDraft.intent.resolvingTime(
                    requestedAt: submittedRequestedAt ?? submittedDraft.intent.requestedAt,
                    meaning: submittedTime,
                    isExplicit: submittedRequestedAt != nil || submittedDraft.intent.timeWasExplicit,
                )
            } else {
                submittedDraft.intent
            }
            draft = NaturalJourneyDraft(
                intent: intent,
                origin: origin,
                destination: destination,
            )
            currentLocation = location
        case let .resolveModeConflict(submittedDraft, location, mode, constraint):
            var requiredModes = submittedDraft.intent.requiredModes
            var excludedModes = submittedDraft.intent.excludedModes
            var preferredModes = submittedDraft.intent.preferredModes
            switch constraint {
            case .required:
                requiredModes.insert(mode)
                excludedModes.remove(mode)
                preferredModes.remove(mode)
            case .excluded:
                requiredModes.remove(mode)
                excludedModes.insert(mode)
                preferredModes.remove(mode)
            case .preferred:
                requiredModes.remove(mode)
                excludedModes.remove(mode)
                preferredModes.insert(mode)
            }
            let intent = submittedDraft.intent.resolvingModes(
                required: requiredModes,
                excluded: excludedModes,
                preferred: preferredModes,
            )
            draft = NaturalJourneyDraft(
                intent: intent,
                origin: submittedDraft.origin,
                destination: submittedDraft.destination,
            )
            currentLocation = location
        case let .continueWithoutUnsupportedConstraints(submittedDraft, location):
            let intent = submittedDraft.intent.ignoringUnsupportedConstraints()
            draft = NaturalJourneyDraft(
                intent: intent,
                origin: submittedDraft.origin,
                destination: submittedDraft.destination,
            )
            currentLocation = location
        case let .resolveTimeConflict(submittedDraft, location, chosen):
            let primary = submittedDraft.intent.requestedAt.map {
                RouteTimeConstraint(
                    requestedAt: $0,
                    meaning: submittedDraft.intent.datetimeRepresents == .arrival ? .arrival : .departure,
                )
            }
            guard chosen == primary || chosen == submittedDraft.intent.alternateTimeConstraint else {
                throw ViaError.invalidRequest("La contrainte horaire choisie ne correspond pas à la demande")
            }
            let intent = submittedDraft.intent.choosingTimeConstraint(chosen)
            draft = NaturalJourneyDraft(
                intent: intent,
                origin: submittedDraft.origin,
                destination: submittedDraft.destination,
            )
            currentLocation = location
        case let .confirmCurrentLocation(submittedDraft, location):
            let intent = submittedDraft.intent.confirmingCurrentLocation()
            draft = NaturalJourneyDraft(
                intent: intent,
                origin: submittedDraft.origin,
                destination: submittedDraft.destination,
            )
            currentLocation = location
        }

        try Task.checkCancellation()
        if draft.intent.scope == .unsupported {
            return .unsupported(message: Self.unsupportedMessage, examples: Self.examples)
        }
        if case .currentLocation = draft.intent.origin,
           !draft.intent.originWasExplicit,
           currentLocation != nil
        {
            return .needsDecision(draft: draft, decision: .currentLocation)
        }

        let conflictingModes = draft.intent.requiredModes.intersection(draft.intent.excludedModes)
        if let mode = conflictingModes.sorted().first {
            return .needsDecision(
                draft: draft,
                decision: .modeConflict(mode, choices: [.required, .excluded]),
            )
        }
        let conflictingPreferences = draft.intent.preferredModes.intersection(
            draft.intent.excludedModes,
        )
        if let mode = conflictingPreferences.sorted().first {
            return .needsDecision(
                draft: draft,
                decision: .modeConflict(mode, choices: [.preferred, .excluded]),
            )
        }
        if !draft.intent.unsupportedConstraints.isEmpty {
            return .needsDecision(
                draft: draft,
                decision: .unsupportedConstraints(draft.intent.unsupportedConstraints),
            )
        }
        if draft.intent.dateWasExplicit, !draft.intent.timeWasExplicit {
            return .needsClarification(
                draft: draft,
                fields: [.init(
                    target: .time,
                    question: "À quelle heure veux-tu voyager ?",
                    candidates: [],
                )],
            )
        }
        if let requestedAt = draft.intent.requestedAt,
           requestedAt < currentTime,
           draft.intent.dateWasExplicit
        {
            return .needsDecision(draft: draft, decision: .pastDate(requestedAt))
        }
        if let requestedAt = draft.intent.requestedAt,
           let alternate = draft.intent.alternateTimeConstraint
        {
            let primaryMeaning: JourneyDatetimeRepresents = draft.intent.datetimeRepresents == .arrival
                ? .arrival
                : .departure
            return .needsDecision(
                draft: draft,
                decision: .timeConflict(
                    RouteTimeConstraint(requestedAt: requestedAt, meaning: primaryMeaning),
                    alternate,
                ),
            )
        }

        let resolved = try await resolveDraft(draft, currentLocation: currentLocation)
        switch resolved {
        case let .clarification(result):
            return result
        case let .resolved(nextDraft):
            draft = nextDraft
        }

        try Task.checkCancellation()
        guard let requestedAt = draft.intent.requestedAt else {
            return .needsClarification(
                draft: draft,
                fields: [.init(target: .time, question: "Pour quand ?", candidates: [])],
            )
        }

        let origin = switch draft.intent.origin {
        case .currentLocation: currentLocation
        case .place: draft.origin?.coordinate
        }
        guard let origin, let destinationResult = draft.destination else {
            return .unavailable(
                message: "J’ai besoin d’un point de départ pour calculer le trajet.",
                guidance: nil,
            )
        }
        guard draft.intent.datetimeRepresents != .ambiguous else {
            return .needsClarification(
                draft: draft,
                fields: [.init(
                    target: .time,
                    question: "Tu veux partir ou arriver à cette heure ?",
                    candidates: [],
                )],
            )
        }

        let destination = JourneyPlaceSelection(destinationResult).journeyDestination
        let timeMeaning: JourneyDatetimeRepresents = draft.intent.datetimeRepresents == .arrival
            ? .arrival
            : .departure
        var journeyRequest = JourneyRequest(origin: origin, destination: destination)
        journeyRequest.limit = 4
        journeyRequest.requestedAt = requestedAt
        journeyRequest.datetimeRepresents = timeMeaning
        journeyRequest.requiredModes = draft.intent.requiredModes
        journeyRequest.excludedModes = draft.intent.excludedModes
        journeyRequest.preferredModes = draft.intent.preferredModes

        let originLabel = switch draft.intent.origin {
        case .currentLocation: "Ta position"
        case .place: draft.origin?.name ?? "Départ"
        }
        let interpretation = NaturalJourneyInterpretation(
            originLabel: originLabel,
            originCoordinate: origin,
            originResult: draft.origin,
            destination: destination,
            destinationResult: destinationResult,
            requestedAt: requestedAt,
            datetimeRepresents: timeMeaning,
            requiredModes: draft.intent.requiredModes,
            excludedModes: draft.intent.excludedModes,
            preferredModes: draft.intent.preferredModes,
        )

        let journeyResult: JourneyResult
        do {
            journeyResult = try await journeys.plan(journeyRequest)
            try Task.checkCancellation()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .networkUnavailable(interpretation: interpretation)
        }

        guard journeyResult.status == .ready, !journeyResult.journeys.isEmpty else {
            return .unavailable(
                message: "Je n’ai pas trouvé d’itinéraire vérifiable.",
                guidance: nil,
            )
        }

        return .ready(
            interpretation: interpretation,
            journeys: journeyResult,
        )
    }

    private func resolveDraft(
        _ draft: NaturalJourneyDraft,
        currentLocation: GeoCoordinate?,
    ) async throws -> DraftResolution {
        var fields: [NaturalJourneyClarification] = []
        var origin = draft.origin
        var destination = draft.destination

        if case .currentLocation = draft.intent.origin, currentLocation == nil {
            fields.append(.init(target: .origin, question: "D’où pars-tu ?", candidates: []))
        } else if case let .place(query) = draft.intent.origin, origin == nil {
            let resolution = try await places.resolve(query, near: currentLocation)
            switch resolution {
            case let .resolved(result):
                origin = result
            case .ambiguous, .notFound, .unavailable:
                fields.append(.init(
                    target: .origin,
                    question: "De quel lieu pars-tu ?",
                    candidates: resolution.candidates,
                ))
            }
        }

        try Task.checkCancellation()
        if let query = draft.intent.destinationQuery, destination == nil {
            let resolution = try await places.resolve(query, near: currentLocation)
            switch resolution {
            case let .resolved(result):
                destination = result
            case .ambiguous, .notFound, .unavailable:
                fields.append(.init(
                    target: .destination,
                    question: "Quel lieu veux-tu choisir ?",
                    candidates: resolution.candidates,
                ))
            }
        } else if draft.intent.destinationQuery == nil {
            fields.append(.init(
                target: .destination,
                question: "Où veux-tu aller ?",
                candidates: [],
            ))
        }

        if draft.intent.datetimeRepresents == .ambiguous {
            fields.append(.init(
                target: .time,
                question: "Tu veux partir ou arriver à cette heure ?",
                candidates: [],
            ))
        }

        let next = NaturalJourneyDraft(
            intent: draft.intent,
            origin: origin,
            destination: destination,
        )
        return fields.isEmpty
            ? .resolved(next)
            : .clarification(.needsClarification(draft: next, fields: fields))
    }

    private func verify(
        _ submitted: SearchResult?,
        near currentLocation: GeoCoordinate?,
    ) async throws -> SearchResult? {
        guard let submitted else { return nil }
        let resolution = try await places.resolve(submitted.name, near: currentLocation)
        switch resolution {
        case let .resolved(result):
            return result.id == submitted.id ? result : nil
        case let .ambiguous(candidates):
            return candidates.first { $0.id == submitted.id }
        case .notFound, .unavailable:
            return nil
        }
    }

    private enum DraftResolution {
        case resolved(NaturalJourneyDraft)
        case clarification(NaturalJourneyResult)
    }

    private func recordInterpretation(startedAt: Date) {
        let duration = max(0, metricsNow().timeIntervalSince(startedAt))
        metrics.recordInterpretation(durationMilliseconds: Int(duration * 1000))
    }

    private static func normalizedTime(in intent: RouteIntent, now: Date) -> RouteIntent {
        if intent.requestedAt == nil, !intent.dateWasExplicit, !intent.timeWasExplicit {
            return intent.replacingRequestedAt(now)
        }
        guard let requestedAt = intent.requestedAt,
              requestedAt < now,
              !intent.dateWasExplicit
        else {
            return intent
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: requestedAt) else {
            return intent
        }
        return intent.replacingRequestedAt(nextDay)
    }
}
