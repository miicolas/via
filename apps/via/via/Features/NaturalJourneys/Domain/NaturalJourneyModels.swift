import Foundation

enum RouteOriginIntent: Sendable, Hashable {
    case currentLocation
    case place(query: String)
}

enum NaturalJourneySavedPlaceKind: String, Sendable, Hashable, Codable {
    case home
    case work
    case custom
}

/// A conversational place never becomes a geocoder query. It can point at a
/// specific confirmed slot or require the only confirmed place in the current
/// search; otherwise the executor asks a targeted question.
enum NaturalJourneyConversationReference: String, Sendable, Hashable, Codable {
    case previousOrigin = "previous_origin"
    case previousDestination = "previous_destination"
    case uniquelyConfirmedPlace = "uniquely_confirmed_place"
}

/// A personal place is identified before any geocoding. `result` never leaves
/// the app: the server adapter sends only an anchored opaque id, generic kind
/// and the words explicitly typed in the current turn.
struct NaturalJourneySavedPlaceReference: Sendable, Hashable {
    let id: String
    let label: String
    let kind: NaturalJourneySavedPlaceKind
    let result: SearchResult?

    init(
        id: String,
        label: String,
        kind: NaturalJourneySavedPlaceKind,
        result: SearchResult?,
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.result = result
    }
}

/// Canonical place vocabulary shared by deterministic grounding, both model
/// adapters, dialogue state and execution. Personal and conversational places
/// can therefore never accidentally become literal geocoding queries.
enum RoutePlaceIntent: Sendable, Hashable {
    case currentLocation
    case saved(NaturalJourneySavedPlaceReference)
    case query(String)
    case reference(NaturalJourneyConversationReference)
}

struct RouteTimeConstraint: Sendable, Hashable {
    let requestedAt: Date
    let meaning: JourneyDatetimeRepresents
}

/// A model can identify what live line information the traveller wants, but
/// never supplies the answer. The executor resolves this intent against Via's
/// official line-status repository.
struct NaturalLineStatusIntent: Sendable, Hashable {
    enum Kind: String, Sendable, Hashable {
        case specific
        case networkOverview = "network_overview"
        case disruptions
    }

    let kind: Kind
    let code: String
    let mode: TransitMode?
    let evidence: String
}

/// One-shot handoff from natural language to the existing Lines experience.
/// A unique official match opens directly; broader questions configure the
/// line browser without generating a prose answer.
struct NaturalLineStatusNavigation: Sendable, Hashable {
    let route: LineStatus?
    let searchText: String
    let mode: TransitMode?
    let disruptionsOnly: Bool
}

struct RouteIntent: Sendable, Hashable {
    enum Scope: String, Sendable, Hashable {
        case journey
        case lineStatus = "line_status"
        case unsupported
    }
    enum TimeMeaning: String, Sendable, Hashable {
        case departure, arrival, ambiguous

        /// The engine only accepts departure or arrival, so `ambiguous` has to
        /// be resolved before this is read.
        var journeyMeaning: JourneyDatetimeRepresents {
            self == .arrival ? .arrival : .departure
        }
    }

    private(set) var scope: Scope
    private(set) var originPlace: RoutePlaceIntent
    private(set) var destinationPlace: RoutePlaceIntent?
    private(set) var requestedAt: Date?
    private(set) var datetimeRepresents: TimeMeaning
    /// « Le dernier train de la journée » — no instant to carry, the anchor is the service day's end.
    private(set) var timeAnchor: JourneyTimeAnchor?
    private(set) var requiredModes: Set<TransitMode>
    private(set) var excludedModes: Set<TransitMode>
    private(set) var preferredModes: Set<TransitMode>
    private(set) var unsupportedConstraints: [String]
    private(set) var dateWasExplicit: Bool
    private(set) var timeWasExplicit: Bool
    private(set) var alternateTimeConstraint: RouteTimeConstraint?
    private(set) var originWasExplicit: Bool
    private(set) var lineStatus: NaturalLineStatusIntent?

    /// Compatibility vocabulary for the existing planning and clarification
    /// views. New understanding code uses the typed place slots above.
    var origin: RouteOriginIntent {
        switch originPlace {
        case .currentLocation:
            .currentLocation
        case .saved(let place):
            .place(query: place.label)
        case .query(let query):
            .place(query: query)
        case .reference(let reference):
            .place(query: reference.rawValue)
        }
    }

    var destinationQuery: String? {
        switch destinationPlace {
        case .currentLocation:
            nil
        case .saved(let place):
            place.label
        case .query(let query):
            query
        case .reference:
            nil
        case nil:
            nil
        }
    }

    init(
        scope: Scope,
        origin: RouteOriginIntent,
        destinationQuery: String?,
        requestedAt: Date?,
        datetimeRepresents: TimeMeaning,
        timeAnchor: JourneyTimeAnchor? = nil,
        requiredModes: Set<TransitMode>,
        excludedModes: Set<TransitMode>,
        preferredModes: Set<TransitMode>,
        unsupportedConstraints: [String] = [],
        dateWasExplicit: Bool = true,
        timeWasExplicit: Bool = true,
        alternateTimeConstraint: RouteTimeConstraint? = nil,
        originWasExplicit: Bool = true,
        lineStatus: NaturalLineStatusIntent? = nil,
    ) {
        self.scope = scope
        originPlace = switch origin {
        case .currentLocation: .currentLocation
        case .place(let query): .query(query)
        }
        destinationPlace = destinationQuery.map(RoutePlaceIntent.query)
        self.requestedAt = requestedAt
        self.datetimeRepresents = datetimeRepresents
        self.timeAnchor = timeAnchor
        self.requiredModes = requiredModes
        self.excludedModes = excludedModes
        self.preferredModes = preferredModes
        self.unsupportedConstraints = unsupportedConstraints
        self.dateWasExplicit = dateWasExplicit
        self.timeWasExplicit = timeWasExplicit
        self.alternateTimeConstraint = alternateTimeConstraint
        self.originWasExplicit = originWasExplicit
        self.lineStatus = lineStatus
    }

    init(
        scope: Scope,
        originPlace: RoutePlaceIntent,
        destinationPlace: RoutePlaceIntent?,
        requestedAt: Date?,
        datetimeRepresents: TimeMeaning,
        timeAnchor: JourneyTimeAnchor? = nil,
        requiredModes: Set<TransitMode>,
        excludedModes: Set<TransitMode>,
        preferredModes: Set<TransitMode>,
        unsupportedConstraints: [String] = [],
        dateWasExplicit: Bool = true,
        timeWasExplicit: Bool = true,
        alternateTimeConstraint: RouteTimeConstraint? = nil,
        originWasExplicit: Bool = true,
        lineStatus: NaturalLineStatusIntent? = nil,
    ) {
        self.scope = scope
        self.originPlace = originPlace
        self.destinationPlace = destinationPlace
        self.requestedAt = requestedAt
        self.datetimeRepresents = datetimeRepresents
        self.timeAnchor = timeAnchor
        self.requiredModes = requiredModes
        self.excludedModes = excludedModes
        self.preferredModes = preferredModes
        self.unsupportedConstraints = unsupportedConstraints
        self.dateWasExplicit = dateWasExplicit
        self.timeWasExplicit = timeWasExplicit
        self.alternateTimeConstraint = alternateTimeConstraint
        self.originWasExplicit = originWasExplicit
        self.lineStatus = lineStatus
    }

    func resolvingTime(
        requestedAt: Date?,
        meaning: JourneyDatetimeRepresents,
        isExplicit: Bool,
    ) -> Self {
        var copy = self
        copy.requestedAt = requestedAt
        copy.datetimeRepresents = meaning == .arrival ? .arrival : .departure
        copy.timeWasExplicit = isExplicit
        return copy
    }

    func resolvingModes(
        required: Set<TransitMode>,
        excluded: Set<TransitMode>,
        preferred: Set<TransitMode>,
    ) -> Self {
        var copy = self
        copy.requiredModes = required
        copy.excludedModes = excluded
        copy.preferredModes = preferred
        return copy
    }

    func ignoringUnsupportedConstraints() -> Self {
        var copy = self
        copy.unsupportedConstraints = []
        return copy
    }

    func choosingTimeConstraint(_ constraint: RouteTimeConstraint) -> Self {
        var copy = resolvingTime(
            requestedAt: constraint.requestedAt,
            meaning: constraint.meaning,
            isExplicit: timeWasExplicit,
        )
        copy.alternateTimeConstraint = nil
        return copy
    }

    func confirmingCurrentLocation() -> Self {
        var copy = self
        copy.originPlace = .currentLocation
        copy.originWasExplicit = true
        return copy
    }

    func replacingPlaces(
        origin: RoutePlaceIntent? = nil,
        destination: RoutePlaceIntent? = nil,
        replaceDestination: Bool = false,
    ) -> Self {
        var copy = self
        if let origin { copy.originPlace = origin }
        if replaceDestination { copy.destinationPlace = destination }
        return copy
    }

    func replacingRequestedAt(_ date: Date) -> Self {
        var copy = self
        copy.requestedAt = date
        return copy
    }

    func replacingTime(from other: Self) -> Self {
        var copy = self
        copy.requestedAt = other.requestedAt
        copy.datetimeRepresents = other.datetimeRepresents
        copy.timeAnchor = other.timeAnchor
        copy.dateWasExplicit = other.dateWasExplicit
        copy.timeWasExplicit = other.timeWasExplicit
        copy.alternateTimeConstraint = other.alternateTimeConstraint
        return copy
    }

    func replacingTimeMeaning(_ meaning: TimeMeaning) -> Self {
        var copy = self
        copy.datetimeRepresents = meaning
        return copy
    }

    func replacingTimeAnchor(_ anchor: JourneyTimeAnchor?) -> Self {
        var copy = self
        copy.timeAnchor = anchor
        if anchor != nil {
            copy.alternateTimeConstraint = nil
            copy.timeWasExplicit = false
        }
        return copy
    }

    func replacingModes(from other: Self) -> Self {
        var copy = self
        copy.requiredModes = other.requiredModes
        copy.excludedModes = other.excludedModes
        copy.preferredModes = other.preferredModes
        return copy
    }

    func replacingUnsupportedConstraints(from other: Self) -> Self {
        var copy = self
        copy.unsupportedConstraints = other.unsupportedConstraints
        return copy
    }

    func replacingScope(_ scope: Scope) -> Self {
        var copy = self
        copy.scope = scope
        return copy
    }
}

struct NaturalJourneyDraft: Sendable, Hashable {
    let dialogueState: NaturalJourneyDialogueState
    let origin: SearchResult?
    let destination: SearchResult?

    var intent: RouteIntent { dialogueState.intent }

    init(
        dialogueState: NaturalJourneyDialogueState,
        origin: SearchResult?,
        destination: SearchResult?,
    ) {
        self.dialogueState = dialogueState
        self.origin = origin
        self.destination = destination
    }

    init(intent: RouteIntent, origin: SearchResult?, destination: SearchResult?) {
        self.init(
            dialogueState: NaturalJourneyDialogueState(intent: intent),
            origin: origin,
            destination: destination,
        )
    }

    /// Answering a decision only revises the intent: the places already
    /// resolved for this draft survive untouched.
    func replacingIntent(_ intent: RouteIntent) -> Self {
        var state = dialogueState
        state.intent = intent
        return NaturalJourneyDraft(
            dialogueState: state,
            origin: origin,
            destination: destination,
        )
    }

    func replacingPlaces(origin: SearchResult?, destination: SearchResult?) -> Self {
        NaturalJourneyDraft(
            dialogueState: dialogueState,
            origin: origin,
            destination: destination,
        )
    }

    func confirming(
        _ field: NaturalJourneyIntentField,
        evidence: String?,
    ) -> Self {
        var state = dialogueState
        state[field: field] = .confirmed(evidence: evidence)
        return NaturalJourneyDraft(
            dialogueState: state,
            origin: origin,
            destination: destination,
        )
    }
}

enum NaturalJourneyRequest: Sendable, Hashable {
    case submit(query: String, currentLocation: GeoCoordinate?)
    case revise(
        query: String,
        draft: NaturalJourneyDraft,
        currentLocation: GeoCoordinate?,
    )
    case resolve(
        draft: NaturalJourneyDraft,
        currentLocation: GeoCoordinate?,
        origin: SearchResult?,
        destination: SearchResult?,
        requestedAt: Date?,
        datetimeRepresents: JourneyDatetimeRepresents?,
    )
    case resolveModeConflict(
        draft: NaturalJourneyDraft,
        currentLocation: GeoCoordinate?,
        mode: TransitMode,
        keeping: NaturalJourneyModeConstraint,
    )
    case continueWithoutUnsupportedConstraints(
        draft: NaturalJourneyDraft,
        currentLocation: GeoCoordinate?,
    )
    case continueAfterUnexplainedText(
        draft: NaturalJourneyDraft,
        currentLocation: GeoCoordinate?,
    )
    case resolveTimeConflict(
        draft: NaturalJourneyDraft,
        currentLocation: GeoCoordinate?,
        keeping: RouteTimeConstraint,
    )
    case confirmCurrentLocation(
        draft: NaturalJourneyDraft,
        currentLocation: GeoCoordinate,
    )
}

enum NaturalJourneyModeConstraint: Sendable, Hashable {
    case required
    case excluded
    case preferred
}

struct NaturalJourneyInterpretation: Sendable, Hashable {
    let originLabel: String
    let originResult: SearchResult?
    let destination: JourneyDestination
    let destinationResult: SearchResult
    let requestedAt: Date
    let datetimeRepresents: JourneyDatetimeRepresents
    /// Present when the phrase asked for the last service of the day.
    let timeAnchor: JourneyTimeAnchor?
    let requiredModes: Set<TransitMode>
    let excludedModes: Set<TransitMode>
    let preferredModes: Set<TransitMode>
    let processingPath: NaturalJourneyProcessingPath

    init(
        originLabel: String,
        originResult: SearchResult? = nil,
        destination: JourneyDestination,
        destinationResult: SearchResult,
        requestedAt: Date,
        datetimeRepresents: JourneyDatetimeRepresents,
        timeAnchor: JourneyTimeAnchor? = nil,
        requiredModes: Set<TransitMode>,
        excludedModes: Set<TransitMode>,
        preferredModes: Set<TransitMode>,
        processingPath: NaturalJourneyProcessingPath = .unknown,
    ) {
        self.originLabel = originLabel
        self.originResult = originResult
        self.destination = destination
        self.destinationResult = destinationResult
        self.requestedAt = requestedAt
        self.datetimeRepresents = datetimeRepresents
        self.timeAnchor = timeAnchor
        self.requiredModes = requiredModes
        self.excludedModes = excludedModes
        self.preferredModes = preferredModes
        self.processingPath = processingPath
    }
}

struct NaturalJourneyCriteria: Sendable, Hashable {
    var originLabel: String
    var destinationResult: SearchResult
    var requestedAt: Date
    var datetimeRepresents: JourneyDatetimeRepresents
    var timeAnchor: JourneyTimeAnchor?
    var requiredModes: Set<TransitMode>
    var excludedModes: Set<TransitMode>
    var preferredModes: Set<TransitMode>
    var processingPath: NaturalJourneyProcessingPath

    init(_ interpretation: NaturalJourneyInterpretation) {
        originLabel = interpretation.originLabel
        destinationResult = interpretation.destinationResult
        requestedAt = interpretation.requestedAt
        datetimeRepresents = interpretation.datetimeRepresents
        timeAnchor = interpretation.timeAnchor
        requiredModes = interpretation.requiredModes
        excludedModes = interpretation.excludedModes
        preferredModes = interpretation.preferredModes
        processingPath = interpretation.processingPath
    }
}

struct NaturalJourneyClarification: Sendable, Hashable, Identifiable {
    enum Target: String, Sendable, Hashable { case origin, destination, time }

    let target: Target
    let question: String
    let candidates: [SearchResult]

    var id: Target { target }
}

enum NaturalJourneyDecision: Sendable, Hashable {
    case currentLocation
    case interpretationConflict([NaturalJourneyIntentField])
    case unexplainedText(String)
    case missingSavedPlace(
        target: NaturalJourneyClarification.Target,
        kind: NaturalJourneySavedPlaceKind,
    )
    case modeConflict(TransitMode, choices: [NaturalJourneyModeConstraint])
    case unsupportedConstraints([String])
    case pastDate(Date)
    case timeConflict(RouteTimeConstraint, RouteTimeConstraint)
}

struct NaturalSavedPlaceSelectionRequest: Sendable, Hashable, Identifiable {
    let id = UUID()
    let draft: NaturalJourneyDraft
    let target: NaturalJourneyClarification.Target
    let kind: NaturalJourneySavedPlaceKind
    let savesPlace: Bool

    var title: String {
        switch (kind, savesPlace) {
        case (.home, true): "Enregistrer Maison"
        case (.work, true): "Enregistrer Travail"
        case (.home, false): "Choisir Maison"
        case (.work, false): "Choisir Travail"
        case (.custom, _): "Choisir un lieu"
        }
    }
}

enum NaturalJourneyUnavailableGuidance: Sendable, Hashable {
    case enableAppleIntelligence
    case modelNotReady
    case systemUnavailable
}

enum NaturalJourneyResult: Sendable, Hashable {
    case ready(
        interpretation: NaturalJourneyInterpretation,
        journeys: JourneyResult,
    )
    case needsClarification(draft: NaturalJourneyDraft, fields: [NaturalJourneyClarification])
    case needsDecision(draft: NaturalJourneyDraft, decision: NaturalJourneyDecision)
    case networkUnavailable(interpretation: NaturalJourneyInterpretation)
    case networkUnavailableDraft(draft: NaturalJourneyDraft)
    case lineStatus(NaturalLineStatusNavigation)
    case unsupported(message: String, examples: [String])
    case unavailable(message: String)
}

extension TransitMode {
    var naturalLanguageName: String {
        switch self {
        case .metro: "métro"
        case .rer: "RER"
        case .transilien: "Transilien"
        case .tram: "tram"
        case .bus: "bus"
        }
    }

    var naturalLanguageNameWithArticle: String { "le \(naturalLanguageName)" }
}
