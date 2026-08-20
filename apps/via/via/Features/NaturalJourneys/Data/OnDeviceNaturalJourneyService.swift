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
            let intent: RouteIntent = if let submittedTime {
                submittedDraft.intent.resolvingTime(
                    requestedAt: submittedRequestedAt ?? submittedDraft.intent.requestedAt,
                    meaning: submittedTime,
                    isExplicit: submittedRequestedAt != nil || submittedDraft.intent.timeWasExplicit,
                )
            } else {
                submittedDraft.intent
            }
            let unresolvedDraft = NaturalJourneyDraft(
                intent: intent,
                origin: submittedOrigin ?? submittedDraft.origin,
                destination: submittedDestination ?? submittedDraft.destination,
            )
            let origin: SearchResult?
            let destination: SearchResult?
            do {
                async let verifiedOrigin = verify(unresolvedDraft.origin, near: location)
                async let verifiedDestination = verify(unresolvedDraft.destination, near: location)
                (origin, destination) = try await (verifiedOrigin, verifiedDestination)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                return .networkUnavailableDraft(draft: unresolvedDraft)
            }
            draft = NaturalJourneyDraft(
                intent: intent,
                origin: origin,
                destination: destination,
            )
            currentLocation = location
        case let .resolveModeConflict(submittedDraft, location, mode, constraint):
            func keeping(
                _ modes: Set<TransitMode>,
                when kept: NaturalJourneyModeConstraint,
            ) -> Set<TransitMode> {
                var modes = modes
                if constraint == kept { modes.insert(mode) } else { modes.remove(mode) }
                return modes
            }
            let intent = submittedDraft.intent.resolvingModes(
                required: keeping(submittedDraft.intent.requiredModes, when: .required),
                excluded: keeping(submittedDraft.intent.excludedModes, when: .excluded),
                preferred: keeping(submittedDraft.intent.preferredModes, when: .preferred),
            )
            draft = submittedDraft.replacingIntent(intent)
            currentLocation = location
        case let .continueWithoutUnsupportedConstraints(submittedDraft, location):
            let intent = submittedDraft.intent.ignoringUnsupportedConstraints()
            draft = submittedDraft.replacingIntent(intent)
            currentLocation = location
        case let .resolveTimeConflict(submittedDraft, location, chosen):
            let primary = submittedDraft.intent.requestedAt.map {
                RouteTimeConstraint(
                    requestedAt: $0,
                    meaning: submittedDraft.intent.datetimeRepresents.journeyMeaning,
                )
            }
            guard chosen == primary || chosen == submittedDraft.intent.alternateTimeConstraint else {
                throw ViaError.invalidRequest("La contrainte horaire choisie ne correspond pas à la demande")
            }
            let intent = submittedDraft.intent.choosingTimeConstraint(chosen)
            draft = submittedDraft.replacingIntent(intent)
            currentLocation = location
        case let .confirmCurrentLocation(submittedDraft, location):
            let intent = submittedDraft.intent.confirmingCurrentLocation()
            draft = submittedDraft.replacingIntent(intent)
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
            return .needsDecision(
                draft: draft,
                decision: .timeConflict(
                    RouteTimeConstraint(
                        requestedAt: requestedAt,
                        meaning: draft.intent.datetimeRepresents.journeyMeaning,
                    ),
                    alternate,
                ),
            )
        }

        let resolved: DraftResolution
        do {
            resolved = try await resolveDraft(draft, currentLocation: currentLocation)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .networkUnavailableDraft(draft: draft)
        }
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
            return .unavailable(message: "J’ai besoin d’un point de départ pour calculer le trajet.")
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
        let timeMeaning = draft.intent.datetimeRepresents.journeyMeaning
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
            return .unavailable(message: "Je n’ai pas trouvé d’itinéraire vérifiable.")
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

        let pendingOriginQuery: String? = if case let .place(query) = draft.intent.origin, origin == nil {
            query
        } else {
            nil
        }
        let pendingDestinationQuery = destination == nil ? draft.intent.destinationQuery : nil

        // The two lookups are independent network searches: waiting for one
        // before starting the other doubled the geocoding latency.
        async let resolvedOrigin = resolve(pendingOriginQuery, near: currentLocation)
        async let resolvedDestination = resolve(pendingDestinationQuery, near: currentLocation)
        let (originResolution, destinationResolution) = try await (resolvedOrigin, resolvedDestination)
        try Task.checkCancellation()

        if case .currentLocation = draft.intent.origin, currentLocation == nil {
            fields.append(.init(target: .origin, question: "D’où pars-tu ?", candidates: []))
        } else if let originResolution {
            switch originResolution {
            case let .resolved(result):
                origin = result
            case .ambiguous, .notFound, .unavailable:
                fields.append(.init(
                    target: .origin,
                    question: "De quel lieu pars-tu ?",
                    candidates: originResolution.candidates,
                ))
            }
        }

        if let destinationResolution {
            switch destinationResolution {
            case let .resolved(result):
                destination = result
            case .ambiguous, .notFound, .unavailable:
                fields.append(.init(
                    target: .destination,
                    question: "Quel lieu veux-tu choisir ?",
                    candidates: destinationResolution.candidates,
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

    private func resolve(
        _ query: String?,
        near currentLocation: GeoCoordinate?,
    ) async throws -> OnDevicePlaceResolution? {
        guard let query else { return nil }
        return try await places.resolve(query, near: currentLocation)
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

    private static let parisCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

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
        guard let nextDay = parisCalendar.date(byAdding: .day, value: 1, to: requestedAt) else {
            return intent
        }
        return intent.replacingRequestedAt(nextDay)
    }
}
