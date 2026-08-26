import Foundation

/// The deep understanding module. Callers submit one turn and optional state;
/// deterministic grounding, model selection, merging and lock enforcement stay
/// behind this interface.
struct ReliableNaturalJourneyUnderstanding: NaturalJourneyUnderstanding {
    private let localModel: any NaturalIntentParsing
    private let remoteModel: (any NaturalIntentParsing)?
    private let savedPlaces: @Sendable () async -> [NaturalJourneySavedPlaceReference]
    private let serverFallbackAllowed: @Sendable () -> Bool

    init(
        localModel: any NaturalIntentParsing,
        remoteModel: (any NaturalIntentParsing)?,
        savedPlaces: @escaping @Sendable () async -> [NaturalJourneySavedPlaceReference],
        serverFallbackAllowed: @escaping @Sendable () -> Bool,
    ) {
        self.localModel = localModel
        self.remoteModel = remoteModel
        self.savedPlaces = savedPlaces
        self.serverFallbackAllowed = serverFallbackAllowed
    }

    var availability: NaturalLanguageAvailability {
        // Deterministic phrases remain available even in Local-only mode on a
        // device that cannot run Foundation Models.
        .available
    }

    func interpret(
        _ turn: NaturalJourneyTurn,
        state: NaturalJourneyDialogueState?,
    ) async throws -> NaturalJourneyTransition {
        let phrase = String(turn.phrase.prefix(500))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { throw NaturalIntentParsingError.invalidResponse }

        let availableSavedPlaces = await savedPlaces()
        let grounding = DeterministicNaturalJourneyGrounder.ground(
            phrase: phrase,
            locale: turn.locale,
            now: turn.now,
            savedPlaces: availableSavedPlaces,
        ).resolvingConversationReferences(in: state)
        if grounding.canBypassModel || (state != nil && grounding.canBypassModelAsRevision) {
            return transition(merging: grounding, into: state)
        }

        let request = NaturalIntentModelRequest(
            phrase: phrase,
            locale: turn.locale,
            now: turn.now,
            hasCurrentLocation: turn.hasCurrentLocation,
            originAnchor: grounding.origin.map {
                NaturalIntentModelAnchor(place: $0.value, evidence: $0.evidence)
            },
            destinationAnchor: grounding.destination.map {
                NaturalIntentModelAnchor(place: $0.value, evidence: $0.evidence)
            },
            savedPlaces: availableSavedPlaces,
        )
        let receivedProposal: NaturalIntentProposal
        let proposalProvenance: NaturalJourneyFieldProvenance
        do {
            receivedProposal = try await localModel.proposeIntent(request)
            proposalProvenance = .localModel
        } catch let error {
            if error == .cancelled { throw error }
            if error == .contentRefused { throw error }
            guard serverFallbackAllowed(), let remoteModel else {
                throw error
            }
            do {
                receivedProposal = try await remoteModel.proposeIntent(request)
                proposalProvenance = .serverModel
            } catch .remoteUnavailable {
                // The server declining (rollout gate, breaker, rate limit) says
                // nothing about the device: surface the local diagnosis, not a
                // fake Apple Intelligence failure.
                throw error
            }
        }
        let proposal = receivedProposal
            .canonicalizingConversationReferences()
            .resolvingConversationReferences(in: state)

        return transition(
            merging: grounding,
            proposal: proposal,
            proposalProvenance: proposalProvenance,
            into: state,
        )
    }

    private func transition(
        merging grounding: NaturalJourneyGrounding,
        proposal: NaturalIntentProposal? = nil,
        proposalProvenance: NaturalJourneyFieldProvenance = .localModel,
        into previous: NaturalJourneyDialogueState?,
    ) -> NaturalJourneyTransition {
        guard let previous else {
            return initialTransition(
                grounding: grounding,
                proposal: proposal,
                proposalProvenance: proposalProvenance,
            )
        }
        return revisionTransition(
            grounding: grounding,
            proposal: proposal,
            previous: previous,
        )
    }

    private func initialTransition(
        grounding: NaturalJourneyGrounding,
        proposal: NaturalIntentProposal?,
        proposalProvenance: NaturalJourneyFieldProvenance,
    ) -> NaturalJourneyTransition {
        var intent = proposal?.intent ?? grounding.partialIntent
        var state = NaturalJourneyDialogueState(intent: intent)
        var changed: Set<NaturalJourneyIntentField> = []
        var conflicts: [NaturalJourneyConflict] = []

        if let proposal {
            state[field: .scope] = .proposed(evidence: nil, provenance: proposalProvenance)
            state[field: .origin] = .proposed(
                evidence: proposal.originEvidence,
                provenance: proposalProvenance,
            )
            if proposal.intent.destinationPlace != nil {
                state[field: .destination] = .proposed(
                    evidence: proposal.destinationEvidence,
                    provenance: proposalProvenance,
                )
            }
            state[field: .time] = .proposed(
                evidence: proposal.timeEvidence,
                provenance: proposalProvenance,
            )
            state[field: .modes] = .proposed(evidence: nil, provenance: proposalProvenance)
            state[field: .unsupportedConstraints] = .proposed(
                evidence: proposal.intent.unsupportedConstraints.first,
                provenance: proposalProvenance,
            )
            changed.formUnion([.scope, .origin, .time, .modes, .unsupportedConstraints])
            if proposal.intent.destinationPlace != nil { changed.insert(.destination) }
        }

        if let origin = grounding.origin {
            if let proposal, proposal.intent.originPlace != origin.value {
                conflicts.append(NaturalJourneyConflict(
                    field: .origin,
                    groundedEvidence: origin.evidence,
                    proposedEvidence: proposal.originEvidence
                        ?? Self.placeDescription(proposal.intent.originPlace),
                ))
            }
            intent = intent.replacingPlaces(origin: origin.value)
            state[field: .origin] = .grounded(
                evidence: origin.evidence,
                provenance: origin.provenance,
            )
            changed.insert(.origin)
        }
        if let destination = grounding.destination {
            if let proposal,
               let proposedDestination = proposal.intent.destinationPlace,
               proposedDestination != destination.value
            {
                conflicts.append(NaturalJourneyConflict(
                    field: .destination,
                    groundedEvidence: destination.evidence,
                    proposedEvidence: proposal.destinationEvidence
                        ?? Self.placeDescription(proposedDestination),
                ))
            }
            intent = intent.replacingPlaces(
                destination: destination.value,
                replaceDestination: true,
            )
            state[field: .destination] = .grounded(
                evidence: destination.evidence,
                provenance: destination.provenance,
            )
            changed.insert(.destination)
        }
        if let time = grounding.timeMeaning {
            if let proposal, proposal.intent.datetimeRepresents != time.value {
                conflicts.append(NaturalJourneyConflict(
                    field: .time,
                    groundedEvidence: time.evidence,
                    proposedEvidence: proposal.timeEvidence,
                ))
            }
            intent = intent.replacingTimeMeaning(time.value)
            state[field: .time] = .grounded(
                evidence: time.evidence,
                provenance: .deterministic,
            )
            changed.insert(.time)
        }
        if let evidence = grounding.timeAnchorEvidence {
            if let proposal, proposal.intent.timeAnchor != .lastOfDay {
                conflicts.append(NaturalJourneyConflict(
                    field: .time,
                    groundedEvidence: evidence,
                    proposedEvidence: proposal.timeEvidence,
                ))
            }
            intent = intent.replacingTimeAnchor(.lastOfDay)
            state[field: .time] = .grounded(
                evidence: evidence,
                provenance: .deterministic,
            )
            changed.insert(.time)
        }
        if let modes = grounding.modes {
            intent = intent.resolvingModes(
                required: modes.required,
                excluded: modes.excluded,
                preferred: modes.preferred,
            )
            state[field: .modes] = .grounded(
                evidence: modes.evidence.joined(separator: " · "),
                provenance: .deterministic,
            )
            changed.insert(.modes)
        }

        state.intent = intent
        return NaturalJourneyTransition(
            state: state,
            changedFields: changed,
            conflicts: conflicts.uniquedByField,
            unexplainedText: proposal?.unexplainedText,
        )
    }

    /// A later turn is a patch, never a fresh interpretation. Only a value
    /// supported by text in that turn may replace a locked slot; implicit
    /// defaults from either model are ignored.
    private func revisionTransition(
        grounding: NaturalJourneyGrounding,
        proposal: NaturalIntentProposal?,
        previous: NaturalJourneyDialogueState,
    ) -> NaturalJourneyTransition {
        var intent = previous.intent
        var state = previous
        var changed: Set<NaturalJourneyIntentField> = []
        var conflicts: [NaturalJourneyConflict] = []

        func recordConflict(
            _ field: NaturalJourneyIntentField,
            previousEvidence: String?,
            proposedEvidence: String?,
        ) {
            conflicts.append(NaturalJourneyConflict(
                field: field,
                groundedEvidence: previousEvidence,
                proposedEvidence: proposedEvidence,
            ))
        }

        func acceptExplicit(
            _ field: NaturalJourneyIntentField,
            evidence: String,
            valuesDiffer: Bool,
            apply: () -> Void,
        ) {
            guard valuesDiffer else { return }
            guard !evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                recordConflict(
                    field,
                    previousEvidence: state[field: field]?.evidence,
                    proposedEvidence: nil,
                )
                return
            }
            apply()
            // The evidence comes from the new user-authored correction, so it
            // becomes the new locked fact regardless of which parser found it.
            state[field: field] = .confirmed(evidence: evidence)
            changed.insert(field)
        }

        if let origin = grounding.origin {
            acceptExplicit(
                .origin,
                evidence: origin.evidence,
                valuesDiffer: intent.originPlace != origin.value,
            ) {
                intent = intent.replacingPlaces(origin: origin.value)
            }
            if let proposal, proposal.intent.originPlace != origin.value,
               proposal.originEvidence != nil
            {
                recordConflict(
                    .origin,
                    previousEvidence: origin.evidence,
                    proposedEvidence: proposal.originEvidence,
                )
            }
        } else if let proposal,
                  let evidence = proposal.originEvidence
        {
            acceptExplicit(
                .origin,
                evidence: evidence,
                valuesDiffer: intent.originPlace != proposal.intent.originPlace,
            ) {
                intent = intent.replacingPlaces(origin: proposal.intent.originPlace)
            }
        }

        if let destination = grounding.destination {
            acceptExplicit(
                .destination,
                evidence: destination.evidence,
                valuesDiffer: intent.destinationPlace != destination.value,
            ) {
                intent = intent.replacingPlaces(
                    destination: destination.value,
                    replaceDestination: true,
                )
            }
            if let proposal,
               let proposed = proposal.intent.destinationPlace,
               proposed != destination.value,
               proposal.destinationEvidence != nil
            {
                recordConflict(
                    .destination,
                    previousEvidence: destination.evidence,
                    proposedEvidence: proposal.destinationEvidence,
                )
            }
        } else if let proposal,
                  let destination = proposal.intent.destinationPlace,
                  let evidence = proposal.destinationEvidence
        {
            acceptExplicit(
                .destination,
                evidence: evidence,
                valuesDiffer: intent.destinationPlace != destination,
            ) {
                intent = intent.replacingPlaces(
                    destination: destination,
                    replaceDestination: true,
                )
            }
        }

        if let proposal, let evidence = proposal.timeEvidence {
            acceptExplicit(
                .time,
                evidence: evidence,
                valuesDiffer: !intent.hasSameTime(as: proposal.intent),
            ) {
                intent = intent.replacingTime(from: proposal.intent)
            }
        }
        if let time = grounding.timeMeaning {
            if let proposal, proposal.intent.datetimeRepresents != time.value {
                recordConflict(
                    .time,
                    previousEvidence: time.evidence,
                    proposedEvidence: proposal.timeEvidence,
                )
            }
            if intent.datetimeRepresents != time.value {
                intent = intent.replacingTimeMeaning(time.value)
                changed.insert(.time)
            }
            state[field: .time] = .confirmed(evidence: time.evidence)
        }
        if let evidence = grounding.timeAnchorEvidence {
            if let proposal, proposal.intent.timeAnchor != .lastOfDay {
                recordConflict(
                    .time,
                    previousEvidence: evidence,
                    proposedEvidence: proposal.timeEvidence,
                )
            }
            intent = intent.replacingTimeAnchor(.lastOfDay)
            state[field: .time] = .confirmed(evidence: evidence)
            changed.insert(.time)
        }
        if let modes = grounding.modes {
            if !modes.matches(intent) {
                intent = intent.resolvingModes(
                    required: modes.required,
                    excluded: modes.excluded,
                    preferred: modes.preferred,
                )
                changed.insert(.modes)
            }
            state[field: .modes] = .confirmed(
                evidence: modes.evidence.joined(separator: " · ")
            )
        } else if let proposal,
           Self.hasExplicitMode(in: proposal, phrase: grounding.phrase),
           !intent.hasSameModes(as: proposal.intent)
        {
            intent = intent.replacingModes(from: proposal.intent)
            state[field: .modes] = .confirmed(evidence: Self.modeEvidence(in: grounding.phrase))
            changed.insert(.modes)
        }
        if let proposal,
           proposal.intent.unsupportedConstraints != intent.unsupportedConstraints,
           !proposal.intent.unsupportedConstraints.isEmpty
        {
            intent = intent.replacingUnsupportedConstraints(from: proposal.intent)
            state[field: .unsupportedConstraints] = .confirmed(
                evidence: proposal.intent.unsupportedConstraints.joined(separator: " · "),
            )
            changed.insert(.unsupportedConstraints)
        }
        if let proposal, proposal.intent.scope == .unsupported {
            intent = intent.replacingScope(.unsupported)
            state[field: .scope] = .confirmed(evidence: nil)
            changed.insert(.scope)
        }

        state.intent = intent
        return NaturalJourneyTransition(
            state: state,
            changedFields: changed,
            conflicts: conflicts.uniquedByField,
            unexplainedText: proposal?.unexplainedText,
        )
    }

    private static func placeDescription(_ place: RoutePlaceIntent) -> String {
        switch place {
        case .currentLocation: "current-location"
        case .saved(let place): place.label
        case .query(let query): query
        case .reference(let reference): reference.rawValue
        }
    }
}

/// Compatibility adapter for existing deterministic execution tests. It keeps
/// the old parser out of callers while the production path uses the reliable
/// grounding module above.
struct ParserBackedNaturalJourneyUnderstanding: NaturalJourneyUnderstanding {
    let parser: any NaturalIntentParsing

    var availability: NaturalLanguageAvailability { parser.availability }

    func interpret(
        _ turn: NaturalJourneyTurn,
        state _: NaturalJourneyDialogueState?,
    ) async throws -> NaturalJourneyTransition {
        let proposal = try await parser.proposeIntent(NaturalIntentModelRequest(
            phrase: turn.phrase,
            locale: turn.locale,
            now: turn.now,
            hasCurrentLocation: turn.hasCurrentLocation,
            originAnchor: nil,
            destinationAnchor: nil,
            savedPlaces: [],
        ))
        return NaturalJourneyTransition(
            state: NaturalJourneyDialogueState(intent: proposal.intent),
            changedFields: [.scope, .origin, .destination, .time, .modes, .unsupportedConstraints],
            conflicts: [],
            unexplainedText: proposal.unexplainedText,
        )
    }
}

private struct GroundedPlace: Sendable, Hashable {
    let value: RoutePlaceIntent
    let evidence: String
    let provenance: NaturalJourneyFieldProvenance

    init(
        value: RoutePlaceIntent,
        evidence: String,
        provenance: NaturalJourneyFieldProvenance = .deterministic,
    ) {
        self.value = value
        self.evidence = evidence
        self.provenance = provenance
    }
}

private struct GroundedTimeMeaning: Sendable, Hashable {
    let value: RouteIntent.TimeMeaning
    let evidence: String
}

private struct GroundedModes: Sendable, Hashable {
    let required: Set<TransitMode>
    let excluded: Set<TransitMode>
    let preferred: Set<TransitMode>
    let evidence: [String]

    func matches(_ intent: RouteIntent) -> Bool {
        required == intent.requiredModes
            && excluded == intent.excludedModes
            && preferred == intent.preferredModes
    }
}

private struct NaturalJourneyGrounding: Sendable, Hashable {
    let phrase: String
    let partialIntent: RouteIntent
    let origin: GroundedPlace?
    let destination: GroundedPlace?
    let timeMeaning: GroundedTimeMeaning?
    let timeAnchorEvidence: String?
    let modes: GroundedModes?
    let fullyCovered: Bool

    var canBypassModel: Bool {
        guard fullyCovered else { return false }
        // A grounded destination with no explicit origin means the current
        // position. It is already a complete journey request and does not need
        // a probabilistic model merely to restate that default.
        if destination != nil { return true }
        return origin?.value.isConversationReference == true
    }

    /// In an active search, a fully grounded field is already a typed patch.
    /// Requiring a model to repeat « non, depuis Opéra » would make an explicit
    /// correction less reliable than the initial request.
    var canBypassModelAsRevision: Bool {
        fullyCovered && (
            origin != nil
                || destination != nil
                || timeMeaning != nil
                || timeAnchorEvidence != nil
                || modes != nil
        )
    }
}

private enum DeterministicNaturalJourneyGrounder {
    static func ground(
        phrase: String,
        locale: Locale,
        now: Date,
        savedPlaces: [NaturalJourneySavedPlaceReference],
    ) -> NaturalJourneyGrounding {
        let isEnglish = locale.language.languageCode?.identifier == "en"
        let pair = routePair(in: phrase, isEnglish: isEnglish)
            ?? destinationThenOriginPair(in: phrase, isEnglish: isEnglish)
        let modes = explicitModes(in: phrase)
        let explicitOrigin = pair?.origin ?? placeAfterOriginMarker(in: phrase, isEnglish: isEnglish)
        let explicitDestination = pair?.destination
            ?? placeAfterDestinationMarker(in: phrase, isEnglish: isEnglish)
            ?? commandDestination(in: phrase, isEnglish: isEnglish)
            ?? (modes == nil ? nil : bareDestinationBeforeConstraint(
                in: phrase,
                isEnglish: isEnglish,
            ))
        let timeMeaning = explicitTimeMeaning(in: phrase, isEnglish: isEnglish)
        let timeAnchorEvidence = lastServiceEvidence(in: phrase, isEnglish: isEnglish)

        let origin = explicitOrigin.map {
            groundedPlace(
                value: $0.value,
                evidence: $0.evidence,
                savedPlaces: savedPlaces,
                isEnglish: isEnglish,
            )
        }
        let destination: GroundedPlace?
        if let explicitDestination {
            destination = groundedPlace(
                value: explicitDestination.value,
                evidence: explicitDestination.evidence,
                savedPlaces: savedPlaces,
                isEnglish: isEnglish,
            )
        } else if let personal = personalPlace(
            in: phrase,
            savedPlaces: savedPlaces,
            isEnglish: isEnglish,
            excluding: explicitOrigin?.value,
        ) {
            destination = GroundedPlace(
                value: .saved(personal.place),
                evidence: personal.evidence,
            )
        } else if let reference = conversationDestinationReference(
            in: phrase,
            isEnglish: isEnglish,
        ) {
            destination = GroundedPlace(
                value: .reference(reference.value),
                evidence: reference.evidence,
            )
        } else {
            destination = nil
        }

        let intent = RouteIntent(
            scope: .journey,
            originPlace: origin?.value ?? .currentLocation,
            destinationPlace: destination?.value,
            requestedAt: now,
            datetimeRepresents: timeMeaning?.value ?? .departure,
            timeAnchor: timeAnchorEvidence == nil ? nil : .lastOfDay,
            requiredModes: modes?.required ?? [],
            excludedModes: modes?.excluded ?? [],
            preferredModes: modes?.preferred ?? [],
            dateWasExplicit: false,
            timeWasExplicit: false,
            originWasExplicit: origin != nil,
        )
        return NaturalJourneyGrounding(
            phrase: phrase,
            partialIntent: intent,
            origin: origin,
            destination: destination,
            timeMeaning: timeMeaning,
            timeAnchorEvidence: timeAnchorEvidence,
            modes: modes,
            fullyCovered: fullyCovered(
                phrase: phrase,
                groundedEvidence: [
                    origin?.evidence,
                    destination?.evidence,
                    timeAnchorEvidence,
                ].compactMap { $0 } + (modes?.evidence ?? []),
                isEnglish: isEnglish,
            ),
        )
    }

    private static func groundedPlace(
        value: String,
        evidence: String,
        savedPlaces: [NaturalJourneySavedPlaceReference],
        isEnglish: Bool,
    ) -> GroundedPlace {
        if let reference = conversationReference(for: value, isEnglish: isEnglish) {
            return GroundedPlace(value: .reference(reference), evidence: evidence)
        }
        if Self.isCurrentLocation(value, isEnglish: isEnglish) {
            return GroundedPlace(value: .currentLocation, evidence: evidence)
        }
        if let saved = personalPlace(
            in: value,
            savedPlaces: savedPlaces,
            isEnglish: isEnglish,
            excluding: nil,
        ) {
            return GroundedPlace(value: .saved(saved.place), evidence: evidence)
        }
        return GroundedPlace(value: .query(value), evidence: evidence)
    }

    /// A deterministic shortcut is allowed only when the remaining words are
    /// harmless route verbs or politeness. A time, mode or unknown constraint
    /// keeps the model in the loop instead of being silently dropped.
    private static func fullyCovered(
        phrase: String,
        groundedEvidence: [String],
        isEnglish: Bool,
    ) -> Bool {
        var residue = OnDevicePlaceResolver.normalize(phrase)
        for evidence in groundedEvidence.sorted(by: { $0.count > $1.count }) {
            residue = residue.replacingOccurrences(
                of: OnDevicePlaceResolver.normalize(evidence),
                with: " ",
            )
        }
        let ignored = isEnglish
            ? Set([
                "get", "take", "bring", "go", "return", "me", "please", "i", "want",
                "would", "like", "no", "but", "from", "frm", "to", "towards",
            ])
            : Set([
                "aller", "allez", "emmene", "emmenez", "ramene", "ramenez", "rentre",
                "rentres", "rentrer", "rentrez", "rentrons", "retour", "retourne",
                "retournez", "retourner", "non", "je", "veux", "voudrais",
                "souhaite", "moi", "s", "il", "vous", "plait", "stp", "svp", "va",
                "vas", "de", "depuis", "depui", "depuiss", "dpeuis", "vers", "a",
                "au", "aux", "direction", "pour", "mais",
                "prendre", "pars", "ensuite",
            ])
        let tokens = residue
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
        return tokens.allSatisfy(ignored.contains)
    }

    private static func personalPlace(
        in phrase: String,
        savedPlaces: [NaturalJourneySavedPlaceReference],
        isEnglish: Bool,
        excluding excludedPlace: String?,
    ) -> (place: NaturalJourneySavedPlaceReference, evidence: String)? {
        let ordered = savedPlaces.flatMap { place -> [(NaturalJourneySavedPlaceReference, String)] in
            let aliases: [String] = switch place.kind {
            case .home:
                isEnglish
                    ? ["at my home", "back home", "my home", "home"]
                    : [
                        "à la maison", "a la maison", "chez-moi", "chez moi", "chez mois",
                        "che moi", "mon domicile", "domicile", "ma maison", "maison",
                    ]
            case .work:
                isEnglish
                    ? ["my workplace", "the office", "work"]
                    : [
                        "à mon travail", "a mon travail", "au travail", "mon travail",
                        "au bureau", "mon bureau", "travail", "bureau", "boulot", "taf",
                    ]
            case .custom:
                [place.label]
            }
            return aliases.map { (place, $0) }
        }.sorted { $0.1.count > $1.1.count }

        for (place, alias) in ordered {
            guard let range = wholePhraseRange(of: alias, in: phrase) else { continue }
            if let excludedPlace,
               OnDevicePlaceResolver.normalize(excludedPlace).contains(
                   OnDevicePlaceResolver.normalize(String(phrase[range])),
               )
            {
                continue
            }
            return (place, String(phrase[range]))
        }
        return nil
    }

    private static func routePair(
        in phrase: String,
        isEnglish: Bool,
    ) -> (
        origin: (value: String, evidence: String),
        destination: (value: String, evidence: String)
    )? {
        let patterns = isEnglish
            ? [#"(?:^|\s)(?:from|frm)\s+(.+?)\s+(?:to|towards)\s+(.+)$"#]
            : [
                #"(?:^|\s)(?:depuis|depui|depuiss|dpeuis|de|au départ de|[àa] partir de)\s+(.+?)\s+(?:vers|jusqu['’]?[àa]|[àa])\s+(.+)$"#,
                #"^((?:la\s+)?gare\s+.+?)\s+pour\s+(?:aller|me rendre|se rendre)(?:\s+ensuite)?\s+(?:[àa]|vers)\s+((?:la\s+)?gare\s+.+)$"#,
            ]
        let fullRange = NSRange(phrase.startIndex..., in: phrase)
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive],
            ),
            let match = expression.firstMatch(in: phrase, range: fullRange),
            let originRange = Range(match.range(at: 1), in: phrase),
            let destinationRange = Range(match.range(at: 2), in: phrase)
            else { continue }

            let origin = trimPlace(String(phrase[originRange]), isEnglish: isEnglish)
            let destination = trimPlace(String(phrase[destinationRange]), isEnglish: isEnglish)
            guard !origin.isEmpty, !destination.isEmpty else { continue }
            return (
                origin: (origin, origin),
                destination: (destination, destination),
            )
        }
        return nil
    }

    /// Natural speech often names the destination first: « emmène-moi à Nation
    /// depuis Auber » / “take me to Nation from Auber”. Preserve the semantic
    /// markers instead of letting a model guess which side is which.
    private static func destinationThenOriginPair(
        in phrase: String,
        isEnglish: Bool,
    ) -> (
        origin: (value: String, evidence: String),
        destination: (value: String, evidence: String)
    )? {
        let pattern = isEnglish
            ? #"(?:^|\s)(?:to|towards)\s+(.+?)\s+(?:from|frm)\s+(.+)$"#
            : #"(?:^|\s)(?:vers|direction|[àa])\s+(.+?)\s+(?:depuis|depui|depuiss|dpeuis)\s+(.+)$"#
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive],
        ) else { return nil }
        let fullRange = NSRange(phrase.startIndex..., in: phrase)
        guard let match = expression.firstMatch(in: phrase, range: fullRange),
              let destinationRange = Range(match.range(at: 1), in: phrase),
              let originRange = Range(match.range(at: 2), in: phrase)
        else { return nil }
        let destination = trimPlace(String(phrase[destinationRange]), isEnglish: isEnglish)
        let origin = trimPlace(String(phrase[originRange]), isEnglish: isEnglish)
        guard !origin.isEmpty,
              !destination.isEmpty,
              destination.range(of: #"^\d{1,2}\s*(?::|h)"#, options: .regularExpression) == nil
        else { return nil }
        return (
            origin: (origin, origin),
            destination: (destination, destination),
        )
    }

    private static func placeAfterOriginMarker(
        in phrase: String,
        isEnglish: Bool,
    ) -> (value: String, evidence: String)? {
        let markers = isEnglish
            ? ["from", "frm"]
            : [
                "depuis", "depui", "depuiss", "dpeuis", "au départ de",
                "a partir de", "à partir de",
            ]
        for marker in markers {
            guard let markerRange = wholePhraseRange(
                of: marker,
                in: phrase,
                backwards: true,
            ) else { continue }
            let rawSuffix = phrase[markerRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .punctuationCharacters)
            let suffix = trimPlace(rawSuffix, isEnglish: isEnglish)
            guard !suffix.isEmpty else { continue }
            return (
                suffix,
                "\(String(phrase[markerRange])) \(suffix)",
            )
        }
        return nil
    }

    private static func placeAfterDestinationMarker(
        in phrase: String,
        isEnglish: Bool,
    ) -> (value: String, evidence: String)? {
        let markers = isEnglish
            ? ["towards", "to"]
            : ["direction", "jusqu’à", "jusqu'a", "vers"]
        for marker in markers {
            guard let markerRange = wholePhraseRange(
                of: marker,
                in: phrase,
                backwards: true,
            ) else { continue }
            let raw = String(phrase[markerRange.upperBound...])
            let value = trimPlace(raw, isEnglish: isEnglish)
            guard !value.isEmpty else { continue }
            return (value, "\(String(phrase[markerRange])) \(value)")
        }
        return nil
    }

    private static func commandDestination(
        in phrase: String,
        isEnglish: Bool,
    ) -> (value: String, evidence: String)? {
        let pattern = isEnglish
            ? #"(?:^|\s)(?:go|get|return|take\s+me|bring\s+me)\s+(?:to|towards)\s+(.+)$"#
            : #"(?:^|\s)(?:aller|allez|va|vas|rentre|rentrez|emm[eè]ne(?:z)?(?:-moi)?|ram[eè]ne(?:z)?(?:-moi)?)\s+(?:[àa]|au|aux|vers)\s+(.+)$"#
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive],
        ), let match = expression.firstMatch(
            in: phrase,
            range: NSRange(phrase.startIndex..., in: phrase),
        ), let range = Range(match.range(at: 1), in: phrase)
        else { return nil }
        let value = trimPlace(String(phrase[range]), isEnglish: isEnglish)
        guard !value.isEmpty else { return nil }
        return (value, value)
    }

    /// A destination can be the bare leading phrase when a recognized mode
    /// constraint follows it: « Nation plutôt en bus mais sans bus ». Requiring
    /// `trimPlace` to remove an actual suffix prevents arbitrary prose from
    /// becoming a geographic query.
    private static func bareDestinationBeforeConstraint(
        in phrase: String,
        isEnglish: Bool,
    ) -> (value: String, evidence: String)? {
        let raw = phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
        let value = trimPlace(raw, isEnglish: isEnglish)
        guard !value.isEmpty,
              OnDevicePlaceResolver.normalize(value) != OnDevicePlaceResolver.normalize(raw)
        else { return nil }
        return (value, value)
    }

    private static func trimPlace(_ raw: String, isEnglish: Bool) -> String {
        let markers = isEnglish
            ? [
                "from", "frm", "to", "towards", "by", "after", "before", "without",
                "with", "only", "prefer", "tomorrow", "today",
            ]
            : [
                "depuis", "depui", "depuiss", "dpeuis", "vers", "direction", "pour",
                "avant", "après", "apres",
                "sans", "avec", "uniquement", "seulement", "plutôt", "plutot",
                "demain", "aujourd’hui", "aujourd'hui",
            ]
        var value = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
        var cut: String.Index?

        func consider(_ index: String.Index) {
            guard index > value.startIndex else { return }
            if cut == nil || index < cut! { cut = index }
        }

        for separator in [",", ";"] {
            if let range = value.range(of: separator) { consider(range.lowerBound) }
        }
        if let timeRange = value.range(
            of: isEnglish
                ? #"\s+at\s+\d{1,2}(?:\s*(?::|h)\s*\d{0,2})?"#
                : #"\s+[àa]\s+\d{1,2}(?:\s*(?::|h)\s*\d{0,2})?"#,
            options: [.regularExpression, .caseInsensitive],
        ) {
            consider(timeRange.lowerBound)
        }
        for marker in markers {
            if let range = wholePhraseRange(of: marker, in: value) {
                consider(range.lowerBound)
            }
        }
        if let cut {
            value = String(value[..<cut])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .punctuationCharacters)
        }
        return value
    }

    private static func conversationReference(
        for value: String,
        isEnglish: Bool,
    ) -> NaturalJourneyConversationReference? {
        let normalized = OnDevicePlaceResolver.normalize(value)
        if isEnglish {
            if ["there", "same place"].contains(normalized) {
                return .uniquelyConfirmedPlace
            }
            if ["same origin", "same departure"].contains(normalized) {
                return .previousOrigin
            }
            if ["same destination"].contains(normalized) {
                return .previousDestination
            }
        } else {
            if ["y", "la", "la bas", "meme endroit", "au meme endroit"].contains(normalized) {
                return .uniquelyConfirmedPlace
            }
            if ["meme origine", "meme depart"].contains(normalized) {
                return .previousOrigin
            }
            if ["meme destination"].contains(normalized) {
                return .previousDestination
            }
        }
        return nil
    }

    private static func conversationDestinationReference(
        in phrase: String,
        isEnglish: Bool,
    ) -> (value: NaturalJourneyConversationReference, evidence: String)? {
        let markers = isEnglish
            ? ["go there", "get there", "take me there", "same destination"]
            : [
                "j’y vais", "j'y vais", "m’y rendre", "m'y rendre", "y aller",
                "aller là-bas", "aller la-bas", "aller là", "même destination",
            ]
        for marker in markers {
            guard let range = wholePhraseRange(of: marker, in: phrase) else { continue }
            let referenceKey: String
            if marker.contains("destination") {
                referenceKey = isEnglish ? "same destination" : "meme destination"
            } else {
                referenceKey = isEnglish ? "there" : "y"
            }
            let reference = conversationReference(
                for: referenceKey,
                isEnglish: isEnglish,
            ) ?? .uniquelyConfirmedPlace
            return (reference, String(phrase[range]))
        }
        return nil
    }

    private static func wholePhraseRange(
        of marker: String,
        in phrase: String,
        backwards: Bool = false,
    ) -> Range<String.Index>? {
        let escaped = NSRegularExpression.escapedPattern(for: marker)
        guard let expression = try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])",
            options: [.caseInsensitive],
        ) else { return nil }
        let matches = expression.matches(
            in: phrase,
            range: NSRange(phrase.startIndex..., in: phrase),
        )
        guard let match = backwards ? matches.last : matches.first else { return nil }
        return Range(match.range, in: phrase)
    }

    private static func isCurrentLocation(_ value: String, isEnglish: Bool) -> Bool {
        let normalized = OnDevicePlaceResolver.normalize(value)
        let aliases = isEnglish
            ? ["here", "my location", "current location"]
            : ["ici", "d ici", "ma position", "position actuelle"]
        return aliases.contains(normalized)
    }

    private static func explicitTimeMeaning(
        in phrase: String,
        isEnglish: Bool,
    ) -> GroundedTimeMeaning? {
        let arrivalMarkers = isEnglish
            ? ["arrive by", "arrive", "before", "by"]
            : ["pour être", "pour etre", "être à", "etre a", "arriver", "avant"]
        let departureMarkers = isEnglish
            ? ["leave", "depart", "after"]
            : ["à partir de", "a partir de", "partir", "départ", "depart", "après", "apres"]
        let arrival = arrivalMarkers.compactMap {
            wholePhraseRange(of: $0, in: phrase).map { String(phrase[$0]) }
        }.first
        let departure = departureMarkers.compactMap {
            wholePhraseRange(of: $0, in: phrase).map { String(phrase[$0]) }
        }.first
        guard (arrival == nil) != (departure == nil) else { return nil }
        if let arrival {
            return GroundedTimeMeaning(value: .arrival, evidence: arrival)
        }
        return GroundedTimeMeaning(value: .departure, evidence: departure!)
    }

    private static func lastServiceEvidence(
        in phrase: String,
        isEnglish: Bool,
    ) -> String? {
        let markers = isEnglish
            ? ["last train", "last subway", "last metro", "last RER", "last bus", "last tram"]
            : [
                "dernier train", "dernier métro", "dernier metro", "dernier RER",
                "dernier bus", "dernier tram",
            ]
        for marker in markers {
            if let range = wholePhraseRange(of: marker, in: phrase) {
                return String(phrase[range])
            }
        }
        return nil
    }

    private static func explicitModes(in phrase: String) -> GroundedModes? {
        let modes: [(TransitMode, String)] = [
            (.metro, #"m[ée]tro"#),
            (.rer, #"RER"#),
            (.transilien, #"Transilien"#),
            (.tram, #"tram(?:way)?"#),
            (.bus, #"bus"#),
        ]
        var required: Set<TransitMode> = []
        var excluded: Set<TransitMode> = []
        var preferred: Set<TransitMode> = []
        var evidence: [String] = []

        for (mode, token) in modes {
            let optionalArticle = #"(?:(?:en|by|le|la|the)\s+|l['’]\s*)?"#
            let requiredPattern =
                #"(?<!\p{L})(?:uniquement|seulement|only)\s+"#
                + optionalArticle + token + #"(?!\p{L})|(?<!\p{L})"#
                + token + #"\s+(?:uniquement|seulement|only)(?!\p{L})"#
            let excludedPattern =
                #"(?<!\p{L})(?:sans|[ée]vite(?:r)?|without|avoid)\s+"#
                + #"(?:(?:prendre|utiliser|taking|using)\s+)?"#
                + optionalArticle + token + #"(?!\p{L})"#
            let preferredPattern =
                #"(?<!\p{L})(?:plut[ôo]t|pr[ée]f[èe]re|prefer)\s+"#
                + optionalArticle + token + #"(?!\p{L})"#

            if let fragment = firstEvidence(matching: requiredPattern, in: phrase) {
                required.insert(mode)
                evidence.append(fragment)
            }
            if let fragment = firstEvidence(matching: excludedPattern, in: phrase) {
                excluded.insert(mode)
                evidence.append(fragment)
            }
            if let fragment = firstEvidence(matching: preferredPattern, in: phrase) {
                preferred.insert(mode)
                evidence.append(fragment)
            }
        }
        guard !required.isEmpty || !excluded.isEmpty || !preferred.isEmpty else { return nil }
        return GroundedModes(
            required: required,
            excluded: excluded,
            preferred: preferred,
            evidence: evidence,
        )
    }

    private static func firstEvidence(
        matching pattern: String,
        in phrase: String,
    ) -> String? {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive],
        ), let match = expression.firstMatch(
            in: phrase,
            range: NSRange(phrase.startIndex..., in: phrase),
        ), let range = Range(match.range, in: phrase)
        else { return nil }
        return String(phrase[range])
    }
}

private extension NaturalJourneyGrounding {
    func resolvingConversationReferences(
        in state: NaturalJourneyDialogueState?
    ) -> Self {
        func resolve(_ place: GroundedPlace?) -> GroundedPlace? {
            guard let place,
                  case let .reference(reference) = place.value,
                  let resolved = state?.resolvedPlace(for: reference)
            else { return place }
            return GroundedPlace(
                value: resolved,
                evidence: place.evidence,
                provenance: .context,
            )
        }

        let resolvedOrigin = resolve(origin)
        let resolvedDestination = resolve(destination)
        return Self(
            phrase: phrase,
            partialIntent: partialIntent.replacingPlaces(
                origin: resolvedOrigin?.value,
                destination: resolvedDestination?.value,
                replaceDestination: destination != nil,
            ),
            origin: resolvedOrigin,
            destination: resolvedDestination,
            timeMeaning: timeMeaning,
            timeAnchorEvidence: timeAnchorEvidence,
            modes: modes,
            fullyCovered: fullyCovered,
        )
    }
}

private extension NaturalIntentProposal {
    func canonicalizingConversationReferences() -> Self {
        func canonical(
            _ place: RoutePlaceIntent,
            evidence: String?
        ) -> RoutePlaceIntent {
            guard case let .query(query) = place else { return place }
            let normalized = OnDevicePlaceResolver.normalize(query)
            let evidenceNormalized = evidence.map(OnDevicePlaceResolver.normalize)
            let values = Set([normalized, evidenceNormalized].compactMap { $0 })
            if !values.isDisjoint(with: ["same origin", "same departure", "meme origine", "meme depart"]) {
                return .reference(.previousOrigin)
            }
            if !values.isDisjoint(with: ["same destination", "meme destination"]) {
                return .reference(.previousDestination)
            }
            if !values.isDisjoint(with: [
                "there", "same place", "y", "la", "la bas", "meme endroit", "au meme endroit",
            ]) {
                return .reference(.uniquelyConfirmedPlace)
            }
            return place
        }

        let origin = canonical(intent.originPlace, evidence: originEvidence)
        let destination = intent.destinationPlace.map {
            canonical($0, evidence: destinationEvidence)
        }
        return Self(
            intent: intent.replacingPlaces(
                origin: origin,
                destination: destination,
                replaceDestination: intent.destinationPlace != nil,
            ),
            originEvidence: originEvidence,
            destinationEvidence: destinationEvidence,
            timeEvidence: timeEvidence,
            unexplainedText: unexplainedText,
        )
    }

    func resolvingConversationReferences(
        in state: NaturalJourneyDialogueState?
    ) -> Self {
        func resolve(_ place: RoutePlaceIntent) -> RoutePlaceIntent {
            guard case let .reference(reference) = place else { return place }
            return state?.resolvedPlace(for: reference) ?? place
        }

        let destination = intent.destinationPlace.map(resolve)
        return Self(
            intent: intent.replacingPlaces(
                origin: resolve(intent.originPlace),
                destination: destination,
                replaceDestination: intent.destinationPlace != nil,
            ),
            originEvidence: originEvidence,
            destinationEvidence: destinationEvidence,
            timeEvidence: timeEvidence,
            unexplainedText: unexplainedText,
        )
    }
}

private extension NaturalJourneyDialogueState {
    func resolvedPlace(
        for reference: NaturalJourneyConversationReference
    ) -> RoutePlaceIntent? {
        func lockedPlace(
            _ field: NaturalJourneyIntentField,
            _ place: RoutePlaceIntent?
        ) -> RoutePlaceIntent? {
            guard self[field: field]?.isLocked == true,
                  let place,
                  !place.isConversationReference
            else { return nil }
            return place
        }

        let origin = lockedPlace(.origin, intent.originPlace)
        let destination = lockedPlace(.destination, intent.destinationPlace)
        switch reference {
        case .previousOrigin:
            return origin
        case .previousDestination:
            return destination
        case .uniquelyConfirmedPlace:
            let candidates = Set([origin, destination].compactMap { $0 })
            return candidates.count == 1 ? candidates.first : nil
        }
    }
}

private extension RoutePlaceIntent {
    var isConversationReference: Bool {
        if case .reference = self { return true }
        return false
    }
}

private extension RouteIntent {
    func hasSameTime(as other: Self) -> Bool {
        requestedAt == other.requestedAt
            && datetimeRepresents == other.datetimeRepresents
            && timeAnchor == other.timeAnchor
            && dateWasExplicit == other.dateWasExplicit
            && timeWasExplicit == other.timeWasExplicit
            && alternateTimeConstraint == other.alternateTimeConstraint
    }

    func hasSameModes(as other: Self) -> Bool {
        requiredModes == other.requiredModes
            && excludedModes == other.excludedModes
            && preferredModes == other.preferredModes
    }
}

private extension ReliableNaturalJourneyUnderstanding {
    static func hasExplicitMode(
        in proposal: NaturalIntentProposal,
        phrase: String,
    ) -> Bool {
        guard !proposal.intent.requiredModes.isEmpty
                || !proposal.intent.excludedModes.isEmpty
                || !proposal.intent.preferredModes.isEmpty
        else { return false }
        let normalized = OnDevicePlaceResolver.normalize(phrase)
        return ["metro", "rer", "transilien", "tram", "bus", "train"]
            .contains { normalized.contains($0) }
    }

    static func modeEvidence(in phrase: String) -> String? {
        let normalized = OnDevicePlaceResolver.normalize(phrase)
        return ["métro", "RER", "Transilien", "tram", "bus", "train"]
            .first { normalized.contains(OnDevicePlaceResolver.normalize($0)) }
    }
}

private extension Array where Element == NaturalJourneyConflict {
    var uniquedByField: Self {
        var seen: Set<NaturalJourneyIntentField> = []
        return filter { seen.insert($0.field).inserted }
    }
}
