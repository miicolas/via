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

    init(
        parser: any NaturalIntentParsing,
        places: OnDevicePlaceResolver,
        journeys: any JourneyRepository,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.parser = parser
        self.places = places
        self.journeys = journeys
        self.now = now
    }

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        let currentTime = now()
        var draft: NaturalJourneyDraft
        let currentLocation: GeoCoordinate?

        switch request {
        case .submit(let query, let location):
            do {
                let intent = try await parser.parseIntent(query, now: currentTime)
                draft = NaturalJourneyDraft(intent: intent, origin: nil, destination: nil)
            } catch NaturalIntentParsingError.cancelled {
                throw CancellationError()
            }
            currentLocation = location
        case .resolve(
            let submittedDraft,
            let location,
            let submittedOrigin,
            let submittedDestination,
            let submittedTime
        ):
            let origin = try await verify(
                submittedOrigin ?? submittedDraft.origin,
                near: location
            )
            try Task.checkCancellation()
            let destination = try await verify(
                submittedDestination ?? submittedDraft.destination,
                near: location
            )
            let intent: RouteIntent
            if let submittedTime {
                intent = RouteIntent(
                    scope: submittedDraft.intent.scope,
                    origin: submittedDraft.intent.origin,
                    destinationQuery: submittedDraft.intent.destinationQuery,
                    requestedAt: submittedDraft.intent.requestedAt,
                    datetimeRepresents: submittedTime == .arrival ? .arrival : .departure,
                    requiredModes: submittedDraft.intent.requiredModes,
                    excludedModes: submittedDraft.intent.excludedModes,
                    preferredModes: submittedDraft.intent.preferredModes
                )
            } else {
                intent = submittedDraft.intent
            }
            draft = NaturalJourneyDraft(
                intent: intent,
                origin: origin,
                destination: destination
            )
            currentLocation = location
        }

        try Task.checkCancellation()
        if draft.intent.scope == .unsupported {
            return .unsupported(message: Self.unsupportedMessage, examples: Self.examples)
        }

        let resolved = try await resolveDraft(draft, currentLocation: currentLocation)
        switch resolved {
        case .clarification(let result):
            return result
        case .resolved(let nextDraft):
            draft = nextDraft
        }

        try Task.checkCancellation()
        guard let requestedAt = draft.intent.requestedAt else {
            return .needsClarification(
                draft: draft,
                fields: [.init(target: .time, question: "Pour quand ?", candidates: [])]
            )
        }

        let origin = switch draft.intent.origin {
        case .currentLocation: currentLocation
        case .place: draft.origin?.coordinate
        }
        guard let origin, let destinationResult = draft.destination else {
            return .unavailable(
                message: "J’ai besoin d’un point de départ pour calculer le trajet.",
                guidance: nil
            )
        }
        guard draft.intent.datetimeRepresents != .ambiguous else {
            return .needsClarification(
                draft: draft,
                fields: [.init(
                    target: .time,
                    question: "Tu veux partir ou arriver à cette heure ?",
                    candidates: []
                )]
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

        var journeyResult = try await journeys.plan(journeyRequest)
        try Task.checkCancellation()
        var lateNotice: String?
        if (journeyResult.status != .ready || journeyResult.journeys.first == nil),
           timeMeaning == .arrival {
            var fallback = journeyRequest
            fallback.requestedAt = currentTime
            fallback.datetimeRepresents = .departure
            let lateResult = try await journeys.plan(fallback)
            try Task.checkCancellation()
            if let first = lateResult.journeys.first, lateResult.status == .ready {
                journeyResult = lateResult
                lateNotice = "Aucun trajet n’arrive à l’heure demandée. Le plus proche arrive à \(Self.parisTime(first.arrivalAt))."
            }
        }

        guard journeyResult.status == .ready, let firstJourney = journeyResult.journeys.first else {
            return .unavailable(
                message: "Je n’ai pas trouvé d’itinéraire vérifiable.",
                guidance: nil
            )
        }

        let preferenceNotice = lateNotice ?? Self.preferredNotice(
            firstJourney,
            modes: draft.intent.preferredModes
        )
        let originLabel = switch draft.intent.origin {
        case .currentLocation: "Ta position"
        case .place: draft.origin?.name ?? "Départ"
        }
        let interpretation = NaturalJourneyInterpretation(
            originLabel: originLabel,
            destination: destination,
            destinationResult: destinationResult,
            requestedAt: requestedAt,
            datetimeRepresents: timeMeaning,
            requiredModes: draft.intent.requiredModes,
            excludedModes: draft.intent.excludedModes,
            preferredModes: draft.intent.preferredModes
        )
        let facts = OnDeviceAnswerFacts(
            originLabel: originLabel,
            destinationLabel: destination.name,
            requestedAt: requestedAt,
            datetimeRepresents: timeMeaning,
            journey: firstJourney,
            preferenceNotice: preferenceNotice
        )
        let generatedAnswer = await parser.writeAnswer(facts)
        try Task.checkCancellation()
        return .ready(
            answer: generatedAnswer ?? OnDeviceAnswerComposer.deterministicAnswer(facts),
            answerSource: generatedAnswer == nil ? .deterministic : .onDevice,
            preferenceNotice: preferenceNotice,
            interpretation: interpretation,
            journeys: journeyResult
        )
    }

    private func resolveDraft(
        _ draft: NaturalJourneyDraft,
        currentLocation: GeoCoordinate?
    ) async throws -> DraftResolution {
        var fields: [NaturalJourneyClarification] = []
        var origin = draft.origin
        var destination = draft.destination

        if case .currentLocation = draft.intent.origin, currentLocation == nil {
            fields.append(.init(target: .origin, question: "D’où pars-tu ?", candidates: []))
        } else if case .place(let query) = draft.intent.origin, origin == nil {
            let resolution = try await places.resolve(query, near: currentLocation)
            switch resolution {
            case .resolved(let result):
                origin = result
            case .ambiguous, .notFound, .unavailable:
                fields.append(.init(
                    target: .origin,
                    question: "De quel lieu pars-tu ?",
                    candidates: resolution.candidates
                ))
            }
        }

        try Task.checkCancellation()
        if let query = draft.intent.destinationQuery, destination == nil {
            let resolution = try await places.resolve(query, near: currentLocation)
            switch resolution {
            case .resolved(let result):
                destination = result
            case .ambiguous, .notFound, .unavailable:
                fields.append(.init(
                    target: .destination,
                    question: "Quel lieu veux-tu choisir ?",
                    candidates: resolution.candidates
                ))
            }
        } else if draft.intent.destinationQuery == nil {
            fields.append(.init(
                target: .destination,
                question: "Où veux-tu aller ?",
                candidates: []
            ))
        }

        if draft.intent.datetimeRepresents == .ambiguous {
            fields.append(.init(
                target: .time,
                question: "Tu veux partir ou arriver à cette heure ?",
                candidates: []
            ))
        }

        let next = NaturalJourneyDraft(
            intent: draft.intent,
            origin: origin,
            destination: destination
        )
        return fields.isEmpty
            ? .resolved(next)
            : .clarification(.needsClarification(draft: next, fields: fields))
    }

    private func verify(
        _ submitted: SearchResult?,
        near currentLocation: GeoCoordinate?
    ) async throws -> SearchResult? {
        guard let submitted else { return nil }
        let resolution = try await places.resolve(submitted.name, near: currentLocation)
        switch resolution {
        case .resolved(let result):
            return result.id == submitted.id ? result : nil
        case .ambiguous(let candidates):
            return candidates.first { $0.id == submitted.id }
        case .notFound, .unavailable:
            return nil
        }
    }

    private static func preferredNotice(
        _ journey: Journey,
        modes: Set<TransitMode>
    ) -> String? {
        guard !modes.isEmpty else { return nil }
        var transitSeconds = 0
        var preferredSeconds = 0
        for section in journey.sections where section.kind == .transit {
            guard let mode = section.route?.mode else { continue }
            transitSeconds += section.durationSeconds
            if modes.contains(mode) { preferredSeconds += section.durationSeconds }
        }
        let labels = modes.sorted().map { $0 == .rer ? "RER" : $0.rawValue }.joined(separator: " ou ")
        let preferredShare = transitSeconds > 0
            ? Double(preferredSeconds) / Double(transitSeconds)
            : 0
        return preferredShare > 0.5
            ? "Cet itinéraire passe majoritairement en \(labels)."
            : "Aucun itinéraire raisonnable majoritairement en \(labels) : voici le meilleur trajet."
    }

    private static func parisTime(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return "\(parts.hour ?? 0) h \(String(format: "%02d", parts.minute ?? 0))"
    }

    private enum DraftResolution {
        case resolved(NaturalJourneyDraft)
        case clarification(NaturalJourneyResult)
    }
}
