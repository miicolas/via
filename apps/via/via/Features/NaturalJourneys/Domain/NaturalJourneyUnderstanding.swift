import Foundation

enum NaturalJourneyIntentField: String, Sendable, Hashable {
    case scope
    case origin
    case destination
    case time
    case modes
    case unsupportedConstraints
}

enum NaturalJourneyFieldProvenance: String, Sendable, Hashable {
    case deterministic
    case localModel
    case serverModel
    case userConfirmed
    case context
}

enum NaturalJourneyFieldConfirmation: String, Sendable, Hashable {
    case proposed
    case grounded
    case confirmed
}

struct NaturalJourneyFieldState: Sendable, Hashable {
    let evidence: String?
    let provenance: NaturalJourneyFieldProvenance
    let confirmation: NaturalJourneyFieldConfirmation

    static func grounded(
        evidence: String,
        provenance: NaturalJourneyFieldProvenance,
    ) -> Self {
        Self(evidence: evidence, provenance: provenance, confirmation: .grounded)
    }

    static func proposed(
        evidence: String?,
        provenance: NaturalJourneyFieldProvenance,
    ) -> Self {
        Self(evidence: evidence, provenance: provenance, confirmation: .proposed)
    }

    static func confirmed(evidence: String?) -> Self {
        Self(evidence: evidence, provenance: .userConfirmed, confirmation: .confirmed)
    }

    var isLocked: Bool { confirmation != .proposed }
}

struct NaturalJourneyDialogueState: Sendable, Hashable {
    var intent: RouteIntent
    private var fields: [NaturalJourneyIntentField: NaturalJourneyFieldState]

    init(
        intent: RouteIntent,
        fields: [NaturalJourneyIntentField: NaturalJourneyFieldState] = [:],
    ) {
        self.intent = intent
        self.fields = fields
    }

    subscript(field field: NaturalJourneyIntentField) -> NaturalJourneyFieldState? {
        get { fields[field] }
        set { fields[field] = newValue }
    }

    var processingPath: NaturalJourneyProcessingPath {
        let provenances = Set(fields.values.map(\.provenance))
        if provenances.contains(.serverModel) { return .serverModel }
        if provenances.contains(.localModel) { return .localModel }
        if provenances.contains(.deterministic) { return .deterministic }
        return .unknown
    }
}

struct NaturalJourneyTurn: Sendable, Hashable {
    let phrase: String
    let locale: Locale
    let now: Date
    let hasCurrentLocation: Bool
    /// The slot whose clarification the person is answering. This is dialogue
    /// state, not something a language model should have to infer again from a
    /// short reply such as « Chatou ».
    let focusedField: NaturalJourneyIntentField?

    init(
        phrase: String,
        locale: Locale,
        now: Date,
        hasCurrentLocation: Bool = false,
        focusedField: NaturalJourneyIntentField? = nil,
    ) {
        self.phrase = phrase
        self.locale = locale
        self.now = now
        self.hasCurrentLocation = hasCurrentLocation
        self.focusedField = focusedField
    }

    init(
        phrase: String,
        now: Date,
        hasCurrentLocation: Bool = false,
        focusedField: NaturalJourneyIntentField? = nil,
    ) {
        self.init(
            phrase: phrase,
            locale: Self.detectedLocale(for: phrase),
            now: now,
            hasCurrentLocation: hasCurrentLocation,
            focusedField: focusedField,
        )
    }

    private static func detectedLocale(for phrase: String) -> Locale {
        let words = Set(OnDevicePlaceResolver.normalize(phrase).split(separator: " ").map(String.init))
        let french = words.intersection([
            "aller", "arriver", "chez", "depuis", "vers", "sans", "travail",
            "bureau", "maison", "rentrer", "rentrez", "metro", "rer", "demain",
            "aujourd", "avant", "apres", "partir", "seulement", "uniquement",
        ]).count
        let english = words.intersection([
            "arrive", "from", "to", "without", "work", "office", "home",
            "get", "take", "subway", "train", "tomorrow", "today", "leave",
            "after", "before", "towards", "please", "only", "prefer",
        ]).count
        if english > french { return Locale(identifier: "en_US") }
        if french > 0 { return Locale(identifier: "fr_FR") }

        let currentCode = Locale.current.language.languageCode?.identifier
        return Locale(identifier: currentCode == "en" ? "en_US" : "fr_FR")
    }
}

struct NaturalJourneyConflict: Sendable, Hashable {
    let field: NaturalJourneyIntentField
    let groundedEvidence: String?
    let proposedEvidence: String?
}

struct NaturalJourneyTransition: Sendable, Hashable {
    let state: NaturalJourneyDialogueState
    let changedFields: Set<NaturalJourneyIntentField>
    let conflicts: [NaturalJourneyConflict]
    let unexplainedText: String?

    init(
        state: NaturalJourneyDialogueState,
        changedFields: Set<NaturalJourneyIntentField>,
        conflicts: [NaturalJourneyConflict],
        unexplainedText: String? = nil,
    ) {
        self.state = state
        self.changedFields = changedFields
        self.conflicts = conflicts
        self.unexplainedText = unexplainedText
    }
}

protocol NaturalJourneyUnderstanding: Sendable {
    var availability: NaturalLanguageAvailability { get }

    func interpret(
        _ turn: NaturalJourneyTurn,
        state: NaturalJourneyDialogueState?,
    ) async throws -> NaturalJourneyTransition
}
