import Foundation
import OSLog
import Observation

private extension NaturalJourneySavedPlaceKind {
    var savedPlaceRole: SavedPlace.Role? {
        switch self {
        case .home: .home
        case .work: .work
        case .custom: nil
        }
    }
}

/// The conversational half of a natural-language search: the composer's state
/// machine, from the first phrase through clarifications and decisions to a
/// finished answer. Understanding itself stays behind
/// `NaturalJourneyRepository` (ADR-0005); every validated interpretation is
/// handed back to `SearchViewModel`, so journey planning stays in one place.
@MainActor
@Observable
final class NaturalJourneyDialogue {
    /// One-shot navigation produced by a finished conversation, consumed by
    /// the map shell: open the journey sheet on the resolved journey, or hand
    /// a line-status question to the Lines tab.
    enum Outcome: Sendable, Hashable {
        case journey(JourneyID)
        case lineStatus(NaturalLineStatusNavigation)
    }

    /// The traveller's reply to the question a panel asked, always about the
    /// draft that panel showed. Every answer patches the draft and re-submits
    /// it through the same pipeline.
    enum Answer: Sendable, Hashable {
        case place(field: NaturalJourneyClarification, candidate: SearchResult)
        case time(requestedAt: Date?, represents: JourneyDatetimeRepresents)
        case modeConflict(mode: TransitMode, keeping: NaturalJourneyModeConstraint)
        case timeConflict(keeping: RouteTimeConstraint)
        case currentLocationConfirmed
        case continueWithoutUnsupportedConstraints
        case continueAfterUnexplainedText
    }

    private(set) var state: NaturalSearchState = .dismissed
    private(set) var unresolvedDraft: NaturalJourneyDraft?
    private(set) var savedPlaceSelectionRequest: NaturalSavedPlaceSelectionRequest?
    private(set) var inputErrorMessage: String?
    private(set) var outcome: Outcome?
    var query = ""

    @ObservationIgnored private let repository: (any NaturalJourneyRepository)?
    @ObservationIgnored private let availability: @Sendable () -> NaturalLanguageAvailability
    @ObservationIgnored private let onboardingStore: any NaturalJourneyOnboardingStoring
    @ObservationIgnored private let metrics: any NaturalJourneyMetricsRecording
    @ObservationIgnored private let locationModel: LocationModel
    @ObservationIgnored private let account: AccountModel?
    /// The planning side of the search surface. The dialogue never plans a
    /// journey itself: it hands interpretations over and tears itself down
    /// when the planner resets.
    @ObservationIgnored private let planner: SearchViewModel
    /// Shared with the planner, which keeps counting corrections once the
    /// interpreted criteria are edited on the classic surface.
    @ObservationIgnored private let corrections: NaturalJourneyCorrectionTally
    @ObservationIgnored private let now: @Sendable () -> Date
    /// Survives the transition from a clarification panel back to the
    /// composer, so a short free-text answer keeps the role of the question
    /// it answers.
    @ObservationIgnored private var focusedField: NaturalJourneyIntentField?
    @ObservationIgnored private var lastRequest: NaturalJourneyRequest?
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var task: Task<Void, Never>?

    init(
        repository: (any NaturalJourneyRepository)? = nil,
        availability: @escaping @Sendable () -> NaturalLanguageAvailability = {
            .unavailable(.deviceNotEligible)
        },
        onboardingStore: (any NaturalJourneyOnboardingStoring)? = nil,
        metrics: any NaturalJourneyMetricsRecording = AppLogNaturalJourneyMetrics(),
        locationModel: LocationModel,
        account: AccountModel? = nil,
        planner: SearchViewModel,
        now: @escaping @Sendable () -> Date = { .now },
    ) {
        self.repository = repository
        self.availability = availability
        self.onboardingStore = onboardingStore ?? UserDefaultsNaturalJourneyOnboardingStore()
        self.metrics = metrics
        self.locationModel = locationModel
        self.account = account
        self.planner = planner
        corrections = planner.naturalCorrections
        self.now = now
        planner.tearDownNaturalSearch = { [weak self] in self?.reset() }
    }

    var access: NaturalLanguageAccess {
        availability().access
    }

    var isPresented: Bool {
        state != .dismissed
    }

    var showsDiscovery: Bool {
        access == .active && !onboardingStore.hasSeenOnboarding
    }

    func open() {
        inputErrorMessage = nil
        switch access {
        case .hidden:
            return
        case .explanation(let guidance):
            state = .availability(guidance)
        case .active:
            state = onboardingStore.hasSeenOnboarding ? .input : .onboarding
        }
    }

    func showInput() {
        onboardingStore.markOnboardingSeen()
        state = .input
    }

    func dismiss() {
        if state == .onboarding {
            onboardingStore.markOnboardingSeen()
        }
        clearConversation()
    }

    /// Everything the dialogue owns back to its resting state, one-shot
    /// outcome included. `SearchViewModel.resetSearch()` reaches this through
    /// the seam installed at construction, so a full reset cannot leave a
    /// conversation behind.
    func reset() {
        clearConversation()
        outcome = nil
        startedAt = nil
    }

    /// Clears the one-shot signal once the shell has navigated on it.
    func consumeOutcome() {
        outcome = nil
    }

    func retry() {
        guard let lastRequest else { return }
        perform(lastRequest)
    }

    func retryAvailability() {
        if let lastRequest {
            perform(lastRequest)
        } else {
            open()
        }
    }

    func submit() {
        let phrase = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard access == .active,
            !phrase.isEmpty,
            repository != nil
        else { return }

        let existingDraft = unresolvedDraft
        if existingDraft == nil {
            startedAt = now()
            corrections.reset()
            planner.clearNaturalCriteria()
        } else {
            corrections.increment()
        }
        inputErrorMessage = nil
        if let existingDraft {
            perform(.revise(
                query: phrase,
                draft: existingDraft,
                focusedField: focusedField,
                currentLocation: locationModel.coordinate,
            ))
        } else {
            perform(.submit(
                query: phrase,
                currentLocation: locationModel.coordinate,
            ))
        }
    }

    func resolve(draft: NaturalJourneyDraft, with answer: Answer) {
        switch answer {
        case let .place(field, candidate):
            guard field.candidates.contains(candidate) else { return }
            let origin = field.target == .origin ? candidate : nil
            let destination = field.target == .destination ? candidate : nil
            guard origin != nil || destination != nil else { return }
            corrections.increment()
            perform(.resolve(
                draft: draft,
                currentLocation: locationModel.coordinate,
                origin: origin,
                destination: destination,
                requestedAt: nil,
                datetimeRepresents: nil,
            ))
        case let .time(requestedAt, represents):
            corrections.increment()
            perform(.resolve(
                draft: draft,
                currentLocation: locationModel.coordinate,
                origin: nil,
                destination: nil,
                requestedAt: requestedAt,
                datetimeRepresents: represents,
            ))
        case let .modeConflict(mode, keeping):
            corrections.increment()
            perform(.resolveModeConflict(
                draft: draft,
                currentLocation: locationModel.coordinate,
                mode: mode,
                keeping: keeping,
            ))
        case let .timeConflict(constraint):
            corrections.increment()
            perform(.resolveTimeConflict(
                draft: draft,
                currentLocation: locationModel.coordinate,
                keeping: constraint,
            ))
        case .currentLocationConfirmed:
            guard let coordinate = locationModel.coordinate else { return }
            corrections.increment()
            perform(.confirmCurrentLocation(
                draft: draft,
                currentLocation: coordinate,
            ))
        case .continueWithoutUnsupportedConstraints:
            corrections.increment()
            perform(.continueWithoutUnsupportedConstraints(
                draft: draft,
                currentLocation: locationModel.coordinate,
            ))
        case .continueAfterUnexplainedText:
            corrections.increment()
            perform(.continueAfterUnexplainedText(
                draft: draft,
                currentLocation: locationModel.coordinate,
            ))
        }
    }

    func chooseSavedPlace(
        draft: NaturalJourneyDraft,
        target: NaturalJourneyClarification.Target,
        kind: NaturalJourneySavedPlaceKind,
        savesPlace: Bool,
    ) {
        savedPlaceSelectionRequest = NaturalSavedPlaceSelectionRequest(
            draft: draft,
            target: target,
            kind: kind,
            savesPlace: savesPlace,
        )
    }

    func cancelSavedPlaceSelection() {
        savedPlaceSelectionRequest = nil
    }

    func completeSavedPlaceSelection(_ result: SearchResult) {
        guard let selection = savedPlaceSelectionRequest else { return }
        savedPlaceSelectionRequest = nil
        if selection.savesPlace, let role = selection.kind.savedPlaceRole {
            account?.setPlace(result, role: role)
        }
        corrections.increment()
        perform(.resolve(
            draft: selection.draft,
            currentLocation: locationModel.coordinate,
            origin: selection.target == .origin ? result : nil,
            destination: selection.target == .destination ? result : nil,
            requestedAt: nil,
            datetimeRepresents: nil,
        ))
    }

    func modifyQuery() {
        switch state {
        case let .clarification(draft, field):
            unresolvedDraft = draft
            focusedField = switch field.target {
            case .origin: .origin
            case .destination: .destination
            case .time: .time
            }
        case let .decision(draft, _):
            unresolvedDraft = draft
            focusedField = nil
        default:
            break
        }
        lastRequest = nil
        inputErrorMessage = nil
        state = .input
    }

    func queryDidChange() {
        inputErrorMessage = nil
    }

    func useClassicSearch() {
        clearConversation()
        planner.exitNaturalSearch()
    }

    private func perform(_ request: NaturalJourneyRequest) {
        guard let repository else { return }
        lastRequest = request
        task?.cancel()
        state = .loading
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await repository.submit(request)
                guard !Task.isCancelled else { return }
                receive(result)
            } catch is CancellationError {
            } catch let error as NaturalIntentParsingError {
                guard !Task.isCancelled else { return }
                AppLog.ai.error(
                    "natural_interpretation_failed reason=\(String(describing: error), privacy: .public)",
                )
                recordMetric(.failure)
                switch error {
                case .modelNotReady:
                    state = .availability(.modelNotReady)
                case .modelFailed:
                    state = .availability(.systemUnavailable)
                case .cancelled:
                    lastRequest = nil
                default:
                    lastRequest = nil
                    inputErrorMessage = Self.inputErrorMessage(for: error)
                    state = .input
                }
            } catch {
                guard !Task.isCancelled else { return }
                recordMetric(.failure)
                state = .failed(message: Self.offlineMessage)
            }
        }
    }

    private func receive(_ result: NaturalJourneyResult) {
        switch result {
        case .ready(let interpretation, let journeys):
            recordMetric(.success, path: interpretation.processingPath)
            planner.applyNaturalInterpretation(interpretation, journeys: journeys)
            if let firstJourney = journeys.journeys.first {
                outcome = .journey(firstJourney.id)
            }
            concludeConversation()
        case .needsClarification(let draft, let fields):
            recordMetric(.clarification, path: draft.dialogueState.processingPath)
            guard let field = fields.first else {
                state = .failed(message: "La demande doit être précisée.")
                return
            }
            unresolvedDraft = draft
            focusedField = switch field.target {
            case .origin: .origin
            case .destination: .destination
            case .time: .time
            }
            state = .clarification(draft: draft, field: field)
        case .needsDecision(let draft, let decision):
            recordMetric(.clarification, path: draft.dialogueState.processingPath)
            unresolvedDraft = draft
            focusedField = nil
            state = .decision(draft: draft, decision: decision)
        case .networkUnavailable(let interpretation):
            recordMetric(.failure, path: interpretation.processingPath)
            planner.applyNaturalInterpretation(interpretation, journeys: nil)
            state = .failed(message: Self.offlineMessage)
        case .networkUnavailableDraft(let draft):
            recordMetric(.failure, path: draft.dialogueState.processingPath)
            planner.clearNaturalCriteria()
            unresolvedDraft = draft
            focusedField = nil
            state = .failed(message: Self.offlineMessage)
        case .lineStatus(let navigation):
            recordMetric(.success)
            outcome = .lineStatus(navigation)
            concludeConversation()
        case .unsupported(let message, let examples):
            recordMetric(.unsupported)
            state = .unsupported(message: message, examples: examples)
        case .unavailable(let message):
            recordMetric(.unavailable)
            state = .failed(message: message)
        }
    }

    /// A conversation that produced its answer: the surface closes and the
    /// phrase is spent, but the one-shot outcome stays for the shell.
    private func concludeConversation() {
        state = .dismissed
        query = ""
        lastRequest = nil
        unresolvedDraft = nil
        focusedField = nil
        savedPlaceSelectionRequest = nil
    }

    /// Everything the conversational surface owns, back to its resting state.
    /// Kept in one place so a new dialogue property cannot be forgotten by
    /// one of the callers that tear the surface down. A pending journey
    /// outcome survives — the shell still has to open the sheet on it.
    private func clearConversation() {
        task?.cancel()
        query = ""
        inputErrorMessage = nil
        lastRequest = nil
        unresolvedDraft = nil
        focusedField = nil
        savedPlaceSelectionRequest = nil
        if case .lineStatus = outcome {
            outcome = nil
        }
        state = .dismissed
    }

    private static let offlineMessage = "Connexion nécessaire pour rechercher les horaires."

    private static func inputErrorMessage(
        for error: NaturalIntentParsingError,
    ) -> String {
        switch error {
        case .unsupportedLanguage:
            "Utilise une phrase en français ou en anglais."
        case .modelBusy:
            "Apple Intelligence est occupé. Réessaie dans un instant."
        case .contextWindowExceeded:
            "Raccourcis ta demande."
        case .contentRefused:
            "Reformule ta demande de trajet."
        case .invalidResponse, .modelFailed:
            "Je n’ai pas compris. Vérifie les lieux et l’heure."
        case .remoteUnavailable:
            "Le service est momentanément indisponible. Réessaie dans un instant."
        case .cancelled, .modelNotReady:
            "La demande n’a pas pu être interprétée."
        }
    }

    private func recordMetric(
        _ outcome: NaturalJourneyMetric.Outcome,
        path: NaturalJourneyProcessingPath = .unknown,
    ) {
        guard let startedAt else { return }
        let duration = max(0, now().timeIntervalSince(startedAt))
        metrics.recordSearch(
            NaturalJourneyMetric(
                outcome: outcome,
                firstResultDurationMilliseconds: outcome == .success
                    ? Int(duration * 1000)
                    : nil,
                correctionCount: corrections.count,
                processingPath: path,
            ))
    }
}
