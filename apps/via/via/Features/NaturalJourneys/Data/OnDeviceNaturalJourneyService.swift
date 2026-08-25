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
            currentLocation = location
        case let .revise(query, submittedDraft, location):
            let interpretationStartedAt = metricsNow()
            do {
                let transition = try await understanding.interpret(
                    NaturalJourneyTurn(
                        phrase: query,
                        now: currentTime,
                        hasCurrentLocation: location != nil,
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

        // The two lookups are independent network searches: waiting for one
        // before starting the other doubled the geocoding latency.
        async let resolvedOrigin = resolve(pendingOriginQuery, near: currentLocation)
        async let resolvedDestination = resolve(pendingDestinationQuery, near: currentLocation)
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

    private func resolve(
        _ query: String?,
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
        return try await places.resolve(query, near: currentLocation)
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
