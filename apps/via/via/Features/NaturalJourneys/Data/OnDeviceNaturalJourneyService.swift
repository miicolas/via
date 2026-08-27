import Foundation

struct OnDeviceNaturalJourneyService: NaturalJourneyRepository {
    private static let unsupportedMessage = "Via peut t’aider à préparer un trajet en Île-de-France"
    private static let examples = [
        "Depuis Châtelet, je veux être à Gare du Nord à 10 h",
        "12 rue de Rivoli avant 9 h",
    ]

    private let understanding: any NaturalJourneyUnderstanding
    private let places: OnDevicePlaceResolver
    private let journeys: any JourneyRepository
    private let lineStatuses: (any LineStatusRepository)?
    private let now: @Sendable () -> Date
    private let metrics: any NaturalJourneyMetricsRecording
    private let metricsNow: @Sendable () -> Date
    private let requiresAccessibleStations: @Sendable () -> Bool
    private let requiresOperationalElevators: @Sendable () -> Bool
    /// The account's Home/Work slot, asked on demand: `AccountModel` lives on
    /// the main actor while this service runs off it, hence the async closure.
    private let favorites: @Sendable (SavedPlace.Role) async -> SearchResult?

    init(
        understanding: any NaturalJourneyUnderstanding,
        places: OnDevicePlaceResolver,
        journeys: any JourneyRepository,
        lineStatuses: (any LineStatusRepository)? = nil,
        now: @escaping @Sendable () -> Date = { .now },
        metrics: any NaturalJourneyMetricsRecording = NoOpNaturalJourneyMetrics(),
        metricsNow: @escaping @Sendable () -> Date = { .now },
        requiresAccessibleStations: @escaping @Sendable () -> Bool = { false },
        requiresOperationalElevators: @escaping @Sendable () -> Bool = { false },
        favorites: @escaping @Sendable (SavedPlace.Role) async -> SearchResult? = { _ in nil },
    ) {
        self.understanding = understanding
        self.places = places
        self.journeys = journeys
        self.lineStatuses = lineStatuses
        self.now = now
        self.metrics = metrics
        self.metricsNow = metricsNow
        self.requiresAccessibleStations = requiresAccessibleStations
        self.requiresOperationalElevators = requiresOperationalElevators
        self.favorites = favorites
    }

    init(
        parser: any NaturalIntentParsing,
        places: OnDevicePlaceResolver,
        journeys: any JourneyRepository,
        lineStatuses: (any LineStatusRepository)? = nil,
        now: @escaping @Sendable () -> Date = { .now },
        metrics: any NaturalJourneyMetricsRecording = NoOpNaturalJourneyMetrics(),
        metricsNow: @escaping @Sendable () -> Date = { .now },
        requiresAccessibleStations: @escaping @Sendable () -> Bool = { false },
        requiresOperationalElevators: @escaping @Sendable () -> Bool = { false },
        favorites: @escaping @Sendable (SavedPlace.Role) async -> SearchResult? = { _ in nil },
    ) {
        self.init(
            understanding: ParserBackedNaturalJourneyUnderstanding(parser: parser),
            places: places,
            journeys: journeys,
            lineStatuses: lineStatuses,
            now: now,
            metrics: metrics,
            metricsNow: metricsNow,
            requiresAccessibleStations: requiresAccessibleStations,
            requiresOperationalElevators: requiresOperationalElevators,
            favorites: favorites,
        )
    }

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        let currentTime = now()
        var draft: NaturalJourneyDraft
        let currentLocation: GeoCoordinate?
        var understandingConflicts: [NaturalJourneyConflict] = []
        var unexplainedText: String? = nil

        switch request {
        case let .submit(query, location):
            let interpretationStartedAt = metricsNow()
            let catalogDraft: NaturalJourneyDraft?
            do {
                catalogDraft = try await catalogGroundedDraft(
                    for: query,
                    now: currentTime,
                    near: location,
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Place resolution will surface its own connectivity state
                // later. A failed preflight must not prevent either model from
                // interpreting a richer sentence.
                catalogDraft = nil
            }
            if let catalogDraft {
                draft = catalogDraft
                recordInterpretation(startedAt: interpretationStartedAt, path: .deterministic)
            } else {
                do {
                    let transition = try await understanding.interpret(
                        NaturalJourneyTurn(
                            phrase: query,
                            now: currentTime,
                            hasCurrentLocation: location != nil,
                        ),
                        state: nil,
                    )
                    recordInterpretation(
                        startedAt: interpretationStartedAt,
                        path: transition.state.processingPath,
                    )
                    var dialogueState = transition.state
                    dialogueState.intent = Self.normalizedTime(
                        in: dialogueState.intent,
                        now: currentTime,
                    )
                    draft = NaturalJourneyDraft(
                        dialogueState: dialogueState,
                        origin: nil,
                        destination: nil,
                    )
                    understandingConflicts = transition.conflicts
                    unexplainedText = transition.unexplainedText
                } catch NaturalIntentParsingError.cancelled {
                    throw CancellationError()
                } catch {
                    recordInterpretation(startedAt: interpretationStartedAt, path: .unknown)
                    throw error
                }
            }
            currentLocation = location
        case let .revise(query, submittedDraft, focusedField, location):
            let interpretationStartedAt = metricsNow()
            do {
                let transition = try await understanding.interpret(
                    NaturalJourneyTurn(
                        phrase: query,
                        now: currentTime,
                        hasCurrentLocation: location != nil,
                        focusedField: focusedField,
                    ),
                    state: submittedDraft.dialogueState,
                )
                recordInterpretation(
                    startedAt: interpretationStartedAt,
                    path: transition.state.processingPath,
                )
                var dialogueState = transition.state
                dialogueState.intent = Self.normalizedTime(
                    in: dialogueState.intent,
                    now: currentTime,
                )
                draft = NaturalJourneyDraft(
                    dialogueState: dialogueState,
                    origin: transition.changedFields.contains(.origin)
                        ? nil
                        : submittedDraft.origin,
                    destination: transition.changedFields.contains(.destination)
                        ? nil
                        : submittedDraft.destination,
                )
                understandingConflicts = transition.conflicts
                unexplainedText = transition.unexplainedText
            } catch NaturalIntentParsingError.cancelled {
                throw CancellationError()
            } catch {
                recordInterpretation(startedAt: interpretationStartedAt, path: .unknown)
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
            var unresolvedDraft = submittedDraft
                .replacingIntent(intent)
                .replacingPlaces(
                    origin: submittedOrigin ?? submittedDraft.origin,
                    destination: submittedDestination ?? submittedDraft.destination,
                )
            if let submittedOrigin {
                unresolvedDraft = unresolvedDraft.confirming(.origin, evidence: submittedOrigin.name)
            }
            if let submittedDestination {
                unresolvedDraft = unresolvedDraft.confirming(
                    .destination,
                    evidence: submittedDestination.name,
                )
            }
            if submittedRequestedAt != nil || submittedTime != nil {
                unresolvedDraft = unresolvedDraft.confirming(.time, evidence: nil)
            }
            let origin: SearchResult?
            let destination: SearchResult?
            let unresolvedOrigin = unresolvedDraft.origin
            let unresolvedDestination = unresolvedDraft.destination
            do {
                async let verifiedOrigin = verify(unresolvedOrigin, near: location)
                async let verifiedDestination = verify(unresolvedDestination, near: location)
                (origin, destination) = try await (verifiedOrigin, verifiedDestination)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                return .networkUnavailableDraft(draft: unresolvedDraft)
            }
            draft = unresolvedDraft.replacingPlaces(origin: origin, destination: destination)
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
            draft = submittedDraft
                .replacingIntent(intent)
                .confirming(.modes, evidence: mode.naturalLanguageName)
            currentLocation = location
        case let .continueWithoutUnsupportedConstraints(submittedDraft, location):
            let intent = submittedDraft.intent.ignoringUnsupportedConstraints()
            draft = submittedDraft
                .replacingIntent(intent)
                .confirming(.unsupportedConstraints, evidence: nil)
            currentLocation = location
        case let .continueAfterUnexplainedText(submittedDraft, location):
            draft = submittedDraft
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
            draft = submittedDraft
                .replacingIntent(intent)
                .confirming(.time, evidence: nil)
            currentLocation = location
        case let .confirmCurrentLocation(submittedDraft, location):
            let intent = submittedDraft.intent.confirmingCurrentLocation()
            draft = submittedDraft
                .replacingIntent(intent)
                .confirming(.origin, evidence: "ma position")
            currentLocation = location
        }

        try Task.checkCancellation()
        if !understandingConflicts.isEmpty {
            let order: [NaturalJourneyIntentField] = [
                .origin, .destination, .time, .modes, .unsupportedConstraints, .scope,
            ]
            let conflicted = Set(understandingConflicts.map(\.field))
            return .needsDecision(
                draft: draft,
                decision: .interpretationConflict(order.filter(conflicted.contains)),
            )
        }
        if let unexplainedText,
           !unexplainedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return .needsDecision(
                draft: draft,
                decision: .unexplainedText(unexplainedText),
            )
        }
        if draft.intent.scope == .lineStatus {
            guard let lineStatus = draft.intent.lineStatus else {
                return .unavailable(message: "Je n’ai pas reconnu la ligne demandée.")
            }
            return await resolveLineStatus(lineStatus)
        }
        if draft.intent.scope == .unsupported {
            return .unsupported(message: Self.unsupportedMessage, examples: Self.examples)
        }
        if case .saved(let place) = draft.intent.originPlace,
           place.result == nil,
           draft.origin == nil
        {
            return .needsDecision(
                draft: draft,
                decision: .missingSavedPlace(target: .origin, kind: place.kind),
            )
        }
        if case .saved(let place) = draft.intent.destinationPlace,
           place.result == nil,
           draft.destination == nil
        {
            return .needsDecision(
                draft: draft,
                decision: .missingSavedPlace(target: .destination, kind: place.kind),
            )
        }
        if case .reference = draft.intent.originPlace, draft.origin == nil {
            return .needsClarification(
                draft: draft,
                fields: [.init(
                    target: .origin,
                    question: "À quel lieu confirmé fais-tu référence pour le départ ?",
                    candidates: Self.contextCandidates(in: draft),
                )],
            )
        }
        if case .reference = draft.intent.destinationPlace, draft.destination == nil {
            return .needsClarification(
                draft: draft,
                fields: [.init(
                    target: .destination,
                    question: "À quel lieu confirmé fais-tu référence ?",
                    candidates: Self.contextCandidates(in: draft),
                )],
            )
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
        // An anchored request (« le dernier train ») names a service, not an
        // instant: there is no time to clarify, no past date, no conflict.
        if draft.intent.timeAnchor == nil {
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
        }

        let resolutionStartedAt = metricsNow()
        let resolved: DraftResolution
        do {
            resolved = try await resolveDraft(draft, currentLocation: currentLocation)
            recordStage(
                .placeResolution,
                startedAt: resolutionStartedAt,
                path: draft.dialogueState.processingPath,
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            recordStage(
                .placeResolution,
                startedAt: resolutionStartedAt,
                path: draft.dialogueState.processingPath,
            )
            return .networkUnavailableDraft(draft: draft)
        }
        switch resolved {
        case let .clarification(result):
            return result
        case let .resolved(nextDraft):
            draft = nextDraft
        }

        try Task.checkCancellation()
        // « Le dernier train » carries no instant: today's service day is the
        // whole answer, so the reference time is simply now.
        guard let requestedAt = draft.intent.requestedAt
            ?? (draft.intent.timeAnchor != nil ? currentTime : nil)
        else {
            return .needsClarification(
                draft: draft,
                fields: [.init(target: .time, question: "Pour quand ?", candidates: [])],
            )
        }

        let origin = switch draft.intent.originPlace {
        case .currentLocation: currentLocation
        case .query, .saved, .reference: draft.origin?.coordinate
        }
        guard let origin, let destinationResult = draft.destination else {
            return .unavailable(message: "J’ai besoin d’un point de départ pour calculer le trajet.")
        }
        guard draft.intent.datetimeRepresents != .ambiguous || draft.intent.timeAnchor != nil else {
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
        let policy = JourneyPlanningPolicy(
            requiredModes: draft.intent.requiredModes,
            excludedModes: draft.intent.excludedModes,
            preferredModes: draft.intent.preferredModes,
            requiresAccessibleStations: requiresAccessibleStations(),
            requiresOperationalElevators: requiresOperationalElevators()
        )
        let originStationID: StationID? = if let origin = draft.origin,
                                             case let .station(station) = origin {
            station.id
        } else {
            nil
        }
        let journeyRequest = JourneyRequest(
            origin: origin,
            destination: destination,
            policy: policy,
            requestedAt: requestedAt,
            datetimeRepresents: timeMeaning,
            timeAnchor: draft.intent.timeAnchor,
            originStationID: originStationID
        )

        let originLabel = switch draft.intent.originPlace {
        case .currentLocation: "Ta position"
        case .query, .saved, .reference: draft.origin?.name ?? "Départ"
        }
        let interpretation = NaturalJourneyInterpretation(
            originLabel: originLabel,
            originResult: draft.origin,
            destination: destination,
            destinationResult: destinationResult,
            requestedAt: requestedAt,
            datetimeRepresents: timeMeaning,
            timeAnchor: draft.intent.timeAnchor,
            requiredModes: draft.intent.requiredModes,
            excludedModes: draft.intent.excludedModes,
            preferredModes: draft.intent.preferredModes,
            processingPath: draft.dialogueState.processingPath,
        )

        let journeyResult: JourneyResult
        let planningStartedAt = metricsNow()
        do {
            journeyResult = try await journeys.plan(journeyRequest)
            try Task.checkCancellation()
            recordStage(
                .planning,
                startedAt: planningStartedAt,
                path: draft.dialogueState.processingPath,
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            recordStage(
                .planning,
                startedAt: planningStartedAt,
                path: draft.dialogueState.processingPath,
            )
            return .networkUnavailable(interpretation: interpretation)
        }

        guard journeyResult.status == .ready, !journeyResult.journeys.isEmpty else {
            let message = switch journeyResult.reason {
            case .noAccessibleRoute:
                "Aucun trajet PMR vérifié ne respecte cette recherche. Modifie la recherche ou désactive le filtre de trajet PMR."
            case .accessibilityDataUnavailable:
                "Les données d’accessibilité sont indisponibles. Réessaie plus tard ou désactive le filtre de trajet PMR."
            case .noOperationalElevatorRoute:
                "Aucun trajet ne passe uniquement par des stations aux ascenseurs vérifiés. Modifie la recherche ou désactive le filtre Ascenseurs."
            case .elevatorDataUnavailable:
                "L’état des ascenseurs est indisponible. Réessaie plus tard ou désactive le filtre Ascenseurs."
            case .transitUnavailable:
                "Le service d’itinéraires ne répond pas. Réessaie dans un instant."
            case nil:
                "Je n’ai pas trouvé d’itinéraire vérifiable."
            }
            return .unavailable(message: message)
        }

        return .ready(
            interpretation: interpretation,
            journeys: journeyResult,
        )
    }

    private func resolveLineStatus(
        _ intent: NaturalLineStatusIntent
    ) async -> NaturalJourneyResult {
        switch intent.kind {
        case .networkOverview:
            return .lineStatus(NaturalLineStatusNavigation(
                route: nil,
                searchText: "",
                mode: intent.mode,
                disruptionsOnly: false,
            ))
        case .disruptions:
            return .lineStatus(NaturalLineStatusNavigation(
                route: nil,
                searchText: "",
                mode: intent.mode,
                disruptionsOnly: true,
            ))
        case .specific:
            guard let lineStatuses else {
                return .unavailable(message: "L’état des lignes est momentanément indisponible.")
            }
            do {
                let board = try await lineStatuses.searchLines(query: intent.code)
                let normalizedCode = OnDevicePlaceResolver.normalize(intent.code)
                let matches = board.lines.filter { status in
                    OnDevicePlaceResolver.normalize(status.route.shortName) == normalizedCode
                        && (intent.mode == nil || status.route.mode == intent.mode)
                }
                guard !matches.isEmpty else {
                    return .unavailable(
                        message: "Je n’ai pas trouvé la ligne \(intent.code) dans le réseau francilien."
                    )
                }
                if matches.count == 1 {
                    return .lineStatus(NaturalLineStatusNavigation(
                        route: matches[0],
                        searchText: intent.code,
                        mode: intent.mode,
                        disruptionsOnly: false,
                    ))
                }
                return .lineStatus(NaturalLineStatusNavigation(
                    route: nil,
                    searchText: intent.code,
                    mode: intent.mode,
                    disruptionsOnly: false,
                ))
            } catch is CancellationError {
                return .unavailable(message: "La consultation de la ligne a été interrompue.")
            } catch {
                return .unavailable(message: "Connexion nécessaire pour consulter l’état des lignes.")
            }
        }
    }

    private func resolveDraft(
        _ draft: NaturalJourneyDraft,
        currentLocation: GeoCoordinate?,
    ) async throws -> DraftResolution {
        var fields: [NaturalJourneyClarification] = []
        var origin = draft.origin
        var destination = draft.destination

        if case .saved(let place) = draft.intent.originPlace, origin == nil {
            origin = place.result
        }
        if case .saved(let place) = draft.intent.destinationPlace, destination == nil {
            destination = place.result
        }

        let customOrigin: NaturalJourneySavedPlaceReference? = if draft.origin == nil,
                                                                  case let .saved(place) = draft.intent.originPlace,
                                                                  place.kind == .custom {
            place
        } else {
            nil
        }
        let customDestination: NaturalJourneySavedPlaceReference? = if draft.destination == nil,
                                                                       case let .saved(place) = draft.intent.destinationPlace,
                                                                       place.kind == .custom {
            place
        } else {
            nil
        }

        let pendingOriginQuery: String? = if case let .query(query) = draft.intent.originPlace,
                                             origin == nil {
            query
        } else {
            nil
        }
        let pendingDestinationQuery: String? = if case let .query(query) = draft.intent.destinationPlace,
                                                  destination == nil {
            query
        } else {
            nil
        }
        let originHint = NaturalPlaceKindHint.inferred(
            from: draft.dialogueState[field: .origin]?.evidence,
        )
        let destinationHint = NaturalPlaceKindHint.inferred(
            from: draft.dialogueState[field: .destination]?.evidence,
        )

        // The two lookups are independent network searches: waiting for one
        // before starting the other doubled the geocoding latency.
        async let resolvedOrigin = resolve(
            pendingOriginQuery,
            hint: originHint,
            near: currentLocation,
        )
        async let resolvedDestination = resolve(
            pendingDestinationQuery,
            hint: destinationHint,
            near: currentLocation,
        )
        async let resolvedCustomOrigin = resolveCustomAlias(customOrigin, near: currentLocation)
        async let resolvedCustomDestination = resolveCustomAlias(customDestination, near: currentLocation)
        let (
            originResolution,
            destinationResolution,
            customOriginResolution,
            customDestinationResolution
        ) = try await (
            resolvedOrigin,
            resolvedDestination,
            resolvedCustomOrigin,
            resolvedCustomDestination,
        )
        try Task.checkCancellation()

        if case .currentLocation = draft.intent.origin, currentLocation == nil {
            fields.append(.init(target: .origin, question: "D’où pars-tu ?", candidates: []))
        } else if case .reference = draft.intent.originPlace, origin == nil {
            fields.append(.init(
                target: .origin,
                question: "À quel lieu confirmé fais-tu référence pour le départ ?",
                candidates: Self.contextCandidates(in: draft),
            ))
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
        } else if let customOriginResolution {
            switch customOriginResolution {
            case let .resolved(result):
                origin = result
            case let .ambiguous(candidates):
                fields.append(.init(
                    target: .origin,
                    question: "Tu parles du lieu enregistré ou du lieu public ?",
                    candidates: candidates,
                ))
            case .notFound, .unavailable:
                break
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
        } else if let customDestinationResolution {
            switch customDestinationResolution {
            case let .resolved(result):
                destination = result
            case let .ambiguous(candidates):
                fields.append(.init(
                    target: .destination,
                    question: "Tu parles du lieu enregistré ou du lieu public ?",
                    candidates: candidates,
                ))
            case .notFound, .unavailable:
                break
            }
        } else if case .reference = draft.intent.destinationPlace, destination == nil {
            fields.append(.init(
                target: .destination,
                question: "À quel lieu confirmé fais-tu référence ?",
                candidates: Self.contextCandidates(in: draft),
            ))
        } else if draft.intent.destinationQuery == nil {
            fields.append(.init(
                target: .destination,
                question: "Où veux-tu aller ?",
                candidates: [],
            ))
        }

        if draft.intent.datetimeRepresents == .ambiguous, draft.intent.timeAnchor == nil {
            fields.append(.init(
                target: .time,
                question: "Tu veux partir ou arriver à cette heure ?",
                candidates: [],
            ))
        }

        let next = draft.replacingPlaces(origin: origin, destination: destination)
        return fields.isEmpty
            ? .resolved(next)
            : .clarification(.needsClarification(draft: next, fields: fields))
    }

    /// Ground terse place-only input with the same authoritative catalog used
    /// for execution. A complete catalog match wins first; otherwise every
    /// token boundary is tried and only one uniquely strong pair is accepted.
    /// This is what makes « Chatou Bonne Nouvelle » deterministic without
    /// teaching a model a brittle list of station names.
    private func catalogGroundedDraft(
        for phrase: String,
        now: Date,
        near currentLocation: GeoCoordinate?,
    ) async throws -> NaturalJourneyDraft? {
        guard Self.looksLikeBarePlaceInput(phrase) else { return nil }

        let whole = try await places.resolve(phrase, near: currentLocation)
        if case .resolved(let destination) = whole,
           OnDevicePlaceResolver.isStrongMatch(destination, for: phrase)
        {
            return Self.catalogDraft(
                originQuery: nil,
                origin: nil,
                destinationQuery: phrase,
                destination: destination,
                now: now,
            )
        }

        let fragments = Self.barePlacePairs(in: phrase)
        guard !fragments.isEmpty else { return nil }
        let matches = try await withThrowingTaskGroup(
            of: CatalogPairMatch?.self,
            returning: [CatalogPairMatch].self,
        ) { group in
            for fragment in fragments {
                group.addTask { [places] in
                    async let originTask = places.resolve(
                        fragment.origin,
                        near: currentLocation,
                    )
                    async let destinationTask = places.resolve(
                        fragment.destination,
                        near: currentLocation,
                    )
                    let (originResolution, destinationResolution) = try await (
                        originTask,
                        destinationTask,
                    )
                    guard case .resolved(let origin) = originResolution,
                          case .resolved(let destination) = destinationResolution,
                          OnDevicePlaceResolver.isStrongMatch(origin, for: fragment.origin),
                          OnDevicePlaceResolver.isStrongMatch(
                              destination,
                              for: fragment.destination,
                          )
                    else { return nil }
                    return CatalogPairMatch(
                        originQuery: fragment.origin,
                        origin: origin,
                        destinationQuery: fragment.destination,
                        destination: destination,
                    )
                }
            }

            var found: [CatalogPairMatch] = []
            for try await match in group {
                if let match { found.append(match) }
            }
            return found
        }

        var seen: Set<String> = []
        let unique = matches.filter {
            seen.insert("\($0.origin.id)|\($0.destination.id)").inserted
        }
        guard unique.count == 1, let pair = unique.first else { return nil }
        return Self.catalogDraft(
            originQuery: pair.originQuery,
            origin: pair.origin,
            destinationQuery: pair.destinationQuery,
            destination: pair.destination,
            now: now,
        )
    }

    private static func catalogDraft(
        originQuery: String?,
        origin: SearchResult?,
        destinationQuery: String,
        destination: SearchResult,
        now: Date,
    ) -> NaturalJourneyDraft {
        let intent = RouteIntent(
            scope: .journey,
            originPlace: originQuery.map(RoutePlaceIntent.query) ?? .currentLocation,
            destinationPlace: .query(destinationQuery),
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            dateWasExplicit: false,
            timeWasExplicit: false,
            originWasExplicit: originQuery != nil,
        )
        var state = NaturalJourneyDialogueState(intent: intent)
        let scopeEvidence = if let originQuery {
            "\(originQuery) \(destinationQuery)"
        } else {
            destinationQuery
        }
        state[field: .scope] = .grounded(
            evidence: scopeEvidence,
            provenance: .deterministic,
        )
        if let originQuery {
            state[field: .origin] = .grounded(
                evidence: originQuery,
                provenance: .deterministic,
            )
        }
        state[field: .destination] = .grounded(
            evidence: destinationQuery,
            provenance: .deterministic,
        )
        return NaturalJourneyDraft(
            dialogueState: state,
            origin: origin,
            destination: destination,
        )
    }

    private static func looksLikeBarePlaceInput(_ phrase: String) -> Bool {
        let raw = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw.count <= 120 else { return false }
        guard raw.range(of: #"[?!;,]"#, options: .regularExpression) == nil else {
            return false
        }
        let words = OnDevicePlaceResolver.normalize(raw)
            .replacingOccurrences(
                of: #"[^\p{L}\p{N}]+"#,
                with: " ",
                options: .regularExpression,
            )
            .split(separator: " ")
            .map(String.init)
        guard (1 ... 7).contains(words.count) else { return false }
        let sentenceVocabulary: Set<String> = [
            "aller", "arrive", "arriver", "cherche", "depuis", "direction",
            "emmene", "jusqu", "pars", "partir", "ramene", "rentre", "vais",
            "vers", "veux", "voudrais", "demain", "aujourd", "matin", "soir",
            "avant", "apres", "dernier", "sans", "seulement", "uniquement",
            "plutot", "prefere", "trafic", "perturbation", "perturbations",
            "ligne", "from", "towards", "leave", "arrive", "tomorrow", "today",
            "before", "after", "without", "only", "prefer", "traffic",
            "comment", "fera", "itineraire", "peux", "pourrais", "quel", "quelle",
            "quelles", "quels", "temps", "trajet", "trouve",
        ]
        guard Set(words).isDisjoint(with: sentenceVocabulary) else { return false }
        return raw.range(
            of: #"\b\d{1,2}\s*(?::|h)\s*\d{0,2}\b"#,
            options: [.regularExpression, .caseInsensitive],
        ) == nil
    }

    private static func barePlacePairs(
        in phrase: String
    ) -> [(origin: String, destination: String)] {
        let words = phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \Character.isWhitespace)
        guard words.count >= 2 else { return [] }
        let nonTerminalConnectors: Set<String> = [
            "a", "au", "aux", "d", "de", "des", "du", "en", "l", "la", "le", "les",
            "of", "the",
        ]
        return (1 ..< words.count).compactMap { boundary in
            let left = words[..<boundary]
            let lastLeft = OnDevicePlaceResolver.normalize(String(left.last!))
                .trimmingCharacters(in: .punctuationCharacters)
            guard !nonTerminalConnectors.contains(lastLeft) else { return nil }
            let origin = left.joined(separator: " ")
            let destination = words[boundary...].joined(separator: " ")
            return (origin, destination)
        }
    }

    private struct CatalogPairMatch: Sendable {
        let originQuery: String
        let origin: SearchResult
        let destinationQuery: String
        let destination: SearchResult
    }

    private func resolve(
        _ query: String?,
        hint: NaturalPlaceKindHint = .automatic,
        near currentLocation: GeoCoordinate?,
    ) async throws -> OnDevicePlaceResolution? {
        guard let query else { return nil }
        // « chez moi » / « au bureau » name a saved place, never a geocodable
        // query. The typed production path handles an absent slot before this
        // seam; the legacy parser path still fails closed here.
        if let role = Self.favoriteRole(for: query) {
            guard let favorite = await favorites(role) else { return .notFound }
            return .resolved(favorite)
        }
        return try await places.resolve(query, hint: hint, near: currentLocation)
    }

    /// Home and Work are personal, unambiguous concepts. A custom alias can
    /// also be a public place name (for example « Bastille »), so both choices
    /// are shown when the local resolver finds a different exact candidate.
    private func resolveCustomAlias(
        _ place: NaturalJourneySavedPlaceReference?,
        near currentLocation: GeoCoordinate?,
    ) async throws -> OnDevicePlaceResolution? {
        guard let place, place.kind == .custom, let saved = place.result else { return nil }
        let publicResolution: OnDevicePlaceResolution
        do {
            publicResolution = try await places.resolve(place.label, near: currentLocation)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .resolved(saved)
        }

        switch publicResolution {
        case let .resolved(result):
            return result.id == saved.id ? .resolved(saved) : .ambiguous([saved, result])
        case let .ambiguous(candidates):
            let distinct = candidates.filter { $0.id != saved.id }
            return distinct.isEmpty ? .resolved(saved) : .ambiguous([saved] + distinct)
        case .notFound, .unavailable:
            return .resolved(saved)
        }
    }

    /// Mirrors the server toolset's HOME/WORK tokens; the queries are compared
    /// accent-insensitively so « à la maison » and « a la maison » both match.
    private static let homeTokens: Set<String> = [
        "maison", "la maison", "a la maison", "chez moi", "home",
    ]
    private static let workTokens: Set<String> = [
        "travail", "le travail", "au travail", "boulot", "le boulot",
        "bureau", "le bureau", "au bureau", "work",
    ]

    private static func favoriteRole(for query: String) -> SavedPlace.Role? {
        let token = OnDevicePlaceResolver.normalize(query)
        if homeTokens.contains(token) { return .home }
        if workTokens.contains(token) { return .work }
        return nil
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

    private static func contextCandidates(in draft: NaturalJourneyDraft) -> [SearchResult] {
        var seen: Set<String> = []
        return [draft.origin, draft.destination]
            .compactMap { $0 }
            .filter { seen.insert($0.id).inserted }
    }

    private func recordInterpretation(
        startedAt: Date,
        path: NaturalJourneyProcessingPath,
    ) {
        recordStage(.interpretation, startedAt: startedAt, path: path)
    }

    private func recordStage(
        _ stage: NaturalJourneyMetricStage,
        startedAt: Date,
        path: NaturalJourneyProcessingPath,
    ) {
        let duration = max(0, metricsNow().timeIntervalSince(startedAt))
        metrics.recordStage(
            stage,
            path: path,
            durationMilliseconds: Int(duration * 1000),
        )
    }

    private static let parisCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    private static func normalizedTime(in intent: RouteIntent, now: Date) -> RouteIntent {
        var normalized = intent
        if !normalized.dateWasExplicit,
           !normalized.timeWasExplicit,
           normalized.datetimeRepresents == .ambiguous
        {
            normalized = normalized.replacingTimeMeaning(.departure)
        }
        if normalized.requestedAt == nil,
           !normalized.dateWasExplicit,
           !normalized.timeWasExplicit
        {
            normalized = normalized.replacingRequestedAt(now)
        }
        guard let requestedAt = normalized.requestedAt,
              requestedAt < now,
              !normalized.dateWasExplicit
        else {
            return normalized
        }
        guard let nextDay = parisCalendar.date(byAdding: .day, value: 1, to: requestedAt) else {
            return normalized
        }
        return normalized.replacingRequestedAt(nextDay)
    }
}
