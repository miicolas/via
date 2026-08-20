import Foundation

enum RouteOriginIntent: Sendable, Hashable {
    case currentLocation
    case place(query: String)
}

struct RouteTimeConstraint: Sendable, Hashable {
    let requestedAt: Date
    let meaning: JourneyDatetimeRepresents
}

struct RouteIntent: Sendable, Hashable {
    enum Scope: String, Sendable, Hashable { case journey, unsupported }
    enum TimeMeaning: String, Sendable, Hashable { case departure, arrival, ambiguous }

    private(set) var scope: Scope
    private(set) var origin: RouteOriginIntent
    private(set) var destinationQuery: String?
    private(set) var requestedAt: Date?
    private(set) var datetimeRepresents: TimeMeaning
    private(set) var requiredModes: Set<TransitMode>
    private(set) var excludedModes: Set<TransitMode>
    private(set) var preferredModes: Set<TransitMode>
    private(set) var unsupportedConstraints: [String]
    private(set) var dateWasExplicit: Bool
    private(set) var timeWasExplicit: Bool
    private(set) var alternateTimeConstraint: RouteTimeConstraint?
    private(set) var originWasExplicit: Bool

    init(
        scope: Scope,
        origin: RouteOriginIntent,
        destinationQuery: String?,
        requestedAt: Date?,
        datetimeRepresents: TimeMeaning,
        requiredModes: Set<TransitMode>,
        excludedModes: Set<TransitMode>,
        preferredModes: Set<TransitMode>,
        unsupportedConstraints: [String] = [],
        dateWasExplicit: Bool = true,
        timeWasExplicit: Bool = true,
        alternateTimeConstraint: RouteTimeConstraint? = nil,
        originWasExplicit: Bool = true,
    ) {
        self.scope = scope
        self.origin = origin
        self.destinationQuery = destinationQuery
        self.requestedAt = requestedAt
        self.datetimeRepresents = datetimeRepresents
        self.requiredModes = requiredModes
        self.excludedModes = excludedModes
        self.preferredModes = preferredModes
        self.unsupportedConstraints = unsupportedConstraints
        self.dateWasExplicit = dateWasExplicit
        self.timeWasExplicit = timeWasExplicit
        self.alternateTimeConstraint = alternateTimeConstraint
        self.originWasExplicit = originWasExplicit
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
        copy.origin = .currentLocation
        copy.originWasExplicit = true
        return copy
    }

    func replacingRequestedAt(_ date: Date) -> Self {
        var copy = self
        copy.requestedAt = date
        return copy
    }
}

struct NaturalJourneyDraft: Sendable, Hashable {
    let intent: RouteIntent
    let origin: SearchResult?
    let destination: SearchResult?
}

enum NaturalJourneyRequest: Sendable, Hashable {
    case submit(query: String, currentLocation: GeoCoordinate?)
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
    let originCoordinate: GeoCoordinate?
    let originResult: SearchResult?
    let destination: JourneyDestination
    let destinationResult: SearchResult
    let requestedAt: Date
    let datetimeRepresents: JourneyDatetimeRepresents
    let requiredModes: Set<TransitMode>
    let excludedModes: Set<TransitMode>
    let preferredModes: Set<TransitMode>

    init(
        originLabel: String,
        originCoordinate: GeoCoordinate? = nil,
        originResult: SearchResult? = nil,
        destination: JourneyDestination,
        destinationResult: SearchResult,
        requestedAt: Date,
        datetimeRepresents: JourneyDatetimeRepresents,
        requiredModes: Set<TransitMode>,
        excludedModes: Set<TransitMode>,
        preferredModes: Set<TransitMode>,
    ) {
        self.originLabel = originLabel
        self.originCoordinate = originCoordinate
        self.originResult = originResult
        self.destination = destination
        self.destinationResult = destinationResult
        self.requestedAt = requestedAt
        self.datetimeRepresents = datetimeRepresents
        self.requiredModes = requiredModes
        self.excludedModes = excludedModes
        self.preferredModes = preferredModes
    }
}

struct NaturalJourneyCriteria: Sendable, Hashable {
    var originLabel: String
    var originCoordinate: GeoCoordinate?
    var originResult: SearchResult?
    var destinationResult: SearchResult
    var requestedAt: Date
    var datetimeRepresents: JourneyDatetimeRepresents
    var requiredModes: Set<TransitMode>
    var excludedModes: Set<TransitMode>
    var preferredModes: Set<TransitMode>

    init(_ interpretation: NaturalJourneyInterpretation) {
        originLabel = interpretation.originLabel
        originCoordinate = interpretation.originCoordinate
        originResult = interpretation.originResult
        destinationResult = interpretation.destinationResult
        requestedAt = interpretation.requestedAt
        datetimeRepresents = interpretation.datetimeRepresents
        requiredModes = interpretation.requiredModes
        excludedModes = interpretation.excludedModes
        preferredModes = interpretation.preferredModes
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
    case modeConflict(TransitMode, choices: [NaturalJourneyModeConstraint])
    case unsupportedConstraints([String])
    case pastDate(Date)
    case timeConflict(RouteTimeConstraint, RouteTimeConstraint)
}

enum NaturalJourneyUnavailableGuidance: Sendable, Hashable {
    case enableAppleIntelligence
    case modelDownloading
}

enum NaturalJourneyResult: Sendable, Hashable {
    case ready(
        interpretation: NaturalJourneyInterpretation,
        journeys: JourneyResult,
    )
    case needsClarification(draft: NaturalJourneyDraft, fields: [NaturalJourneyClarification])
    case needsDecision(draft: NaturalJourneyDraft, decision: NaturalJourneyDecision)
    case networkUnavailable(interpretation: NaturalJourneyInterpretation)
    case unsupported(message: String, examples: [String])
    case unavailable(message: String, guidance: NaturalJourneyUnavailableGuidance?)
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

    var naturalLanguageTitle: String {
        switch self {
        case .metro: "Métro"
        case .rer: "RER"
        case .transilien: "Transilien"
        case .tram: "Tram"
        case .bus: "Bus"
        }
    }

    var naturalLanguageNameWithArticle: String {
        switch self {
        case .metro: "le métro"
        case .rer: "le RER"
        case .transilien: "le Transilien"
        case .tram: "le tram"
        case .bus: "le bus"
        }
    }
}
