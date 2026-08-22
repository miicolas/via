import Foundation
import Observation

@MainActor
@Observable
final class ActiveJourneyModel: ActiveJourneyProvider {
    private(set) var session: ActiveJourneySession?
    private(set) var alternative: ActiveJourneyAlternative?
    private(set) var arrival: JourneyArrival?
    private(set) var recalculationState: ActiveJourneyRecalculationState = .idle
    private(set) var referenceDate: Date
    private(set) var requiresResume = false
    private(set) var isConnected: Bool

    @ObservationIgnored private let locationModel: LocationModel
    @ObservationIgnored private let journeyRepository: any JourneyRepository
    @ObservationIgnored private let store: any ActiveJourneyStore
    @ObservationIgnored private let activityManager: any JourneyActivityManaging
    @ObservationIgnored private let journeyNotificationManager: any JourneyNotificationActiveJourneyManaging
    @ObservationIgnored private let connectivity: any ConnectivityMonitoring
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var locationTask: Task<Void, Never>?
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?
    @ObservationIgnored private var recalculationTask: Task<Void, Never>?
    @ObservationIgnored private var recalculationID: UUID?
    @ObservationIgnored private var lastAutomaticRecalculationSectionID: String?
    @ObservationIgnored private var isRestoring = false
    @ObservationIgnored private var restoreWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        locationModel: LocationModel,
        journeyRepository: any JourneyRepository,
        store: any ActiveJourneyStore = InMemoryActiveJourneyStore(),
        activityManager: any JourneyActivityManaging = NoOpJourneyActivityManager(),
        journeyNotificationManager: any JourneyNotificationActiveJourneyManaging = NoOpJourneyNotificationActiveJourneyManager(),
        connectivity: any ConnectivityMonitoring = InMemoryConnectivityMonitor(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.locationModel = locationModel
        self.journeyRepository = journeyRepository
        self.store = store
        self.activityManager = activityManager
        self.journeyNotificationManager = journeyNotificationManager
        self.connectivity = connectivity
        self.now = now
        referenceDate = now()
        isConnected = connectivity.isConnected
        connectivity.onChange = { [weak self] isConnected in
            self?.connectivityChanged(isConnected)
        }
        connectivity.start()
    }

    var isActive: Bool { session != nil }
    var isTracking: Bool { session?.isTrackingStarted == true && !requiresResume }

    /// Guidance is running: a session under way that has not arrived yet. The
    /// journey sheet sizes its peek on this and the strip shows at that peek, so
    /// the two must be asking the model, not each other.
    var isGuiding: Bool { isActive && arrival == nil }

    /// There is a journey surface to show — the running panel, or the arrival
    /// that outlives the session.
    var hasSurface: Bool { isActive || arrival != nil }

    var journey: Journey? { session?.journey }
    var mapPresentation: JourneyMapPresentation? {
        journey.map(JourneyMapPresentation.init)
    }
    var highlightedSectionID: String? { session?.currentSection?.id }

    /// Continuous position along the journey, for the timeline cursor, the
    /// route dimming on the map and the Live Activity.
    ///
    /// Recomputed rather than stored: `referenceDate` is already bumped on every
    /// monitoring tick and every location sample, so the value stays fresh
    /// without a second source of truth to keep in sync.
    var progress: JourneyProgress? { progress(at: referenceDate) }

    /// The one sentence describing what to do now, shared by the guidance
    /// header, the tab bar accessory and the Live Activity.
    var guidanceHeadline: JourneyGuidanceHeadline? { guidanceHeadline(at: referenceDate) }

    func progress(at date: Date) -> JourneyProgress? {
        guard let session else { return nil }
        return JourneyProgressProjector.progress(
            schedule: ActiveJourneyRules.schedule(for: session.journey),
            sectionIndex: session.currentSectionIndex,
            at: date,
            coordinate: session.lastCoordinate,
            horizontalAccuracy: session.horizontalAccuracy
        )
    }

    func guidanceHeadline(at date: Date) -> JourneyGuidanceHeadline? {
        guard let session, let progress = progress(at: date) else { return nil }
        return JourneyGuidance.headline(
            journey: session.journey,
            schedule: ActiveJourneyRules.schedule(for: session.journey),
            progress: progress,
            at: date,
            isPaused: requiresResume
        )
    }
    var destinationName: String { session?.destination.name ?? "Destination" }
    var phase: ActiveJourneyPhase { phase(at: referenceDate) }

    /// The current step is now described by `guidanceHeadline`; only the
    /// look-ahead survives, for the Live Activity's "Ensuite" line.
    var nextInstruction: ActiveJourneyInstruction? {
        guard let session else { return nil }
        return instruction(at: session.currentSectionIndex + 1)
    }

    var isOffline: Bool { !isConnected || recalculationState == .offline }
    var canRecalculate: Bool { isConnected }
    var hasBackgroundLocationAuthorization: Bool {
        locationModel.backgroundAuthorizationGranted
    }
    var expectsBackgroundTracking: Bool {
        session?.allowsBackgroundTracking == true
    }
    var hasLocationFix: Bool { session?.lastCoordinate != nil }

    func phase(at date: Date) -> ActiveJourneyPhase {
        guard let journey else { return .underway }
        let interval = journey.departureAt.timeIntervalSince(date)
        return interval > 0 ? .scheduled(interval) : .underway
    }

    func activationAction(for journey: Journey, at date: Date) -> JourneyActivationAction {
        guard session?.journey.id == journey.id else {
            return ActiveJourneyRules.activationAction(for: journey, now: date)
        }
        return requiresResume ? .resume : .active
    }

    func activeJourney() async -> ActiveJourneyContext? {
        guard let session else { return nil }
        return ActiveJourneyContext(
            journeyID: session.journey.id,
            lineID: session.currentSection?.route?.id,
            vehicleID: nil
        )
    }

    /// Remembers a future journey and starts its countdown without requesting location.
    func activate(
        journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        planningPolicy: JourneyPlanningPolicy = JourneyPlanningPolicy()
    ) async {
        await begin(
            journey: journey,
            destination: destination,
            source: source,
            planningPolicy: planningPolicy
        )
    }

    /// Starts a journey immediately, after the UI has explained location usage.
    func go(
        journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        planningPolicy: JourneyPlanningPolicy = JourneyPlanningPolicy(),
        allowsBackgroundTracking: Bool
    ) async {
        if session?.journey.id != journey.id {
            await begin(
                journey: journey,
                destination: destination,
                source: source,
                planningPolicy: planningPolicy
            )
        }
        await startTracking(allowsBackgroundTracking: allowsBackgroundTracking)
    }

    func startTracking(allowsBackgroundTracking: Bool) async {
        guard var session else { return }
        let journeyID = session.journey.id
        referenceDate = now()
        guard !ActiveJourneyRules.isExpired(session.journey, at: referenceDate) else {
            await expireJourney()
            return
        }

        requiresResume = false
        session.isTrackingStarted = true
        session.allowsBackgroundTracking = allowsBackgroundTracking
        self.session = session
        await persist()

        let coordinate = await locationModel.requestFreshLocation()
        guard var current = self.session, current.journey.id == journeyID else { return }
        referenceDate = now()
        current.lastCoordinate = coordinate
        current.horizontalAccuracy = nil
        self.session = current

        startLocationTracking(allowsBackgroundUpdates: allowsBackgroundTracking)
        startTimeMonitoring()
        await persist()
        await journeyNotificationManager.registerActiveJourney(session.journey)
        await startActivity()
    }

    func restore() async {
        guard session == nil else { return }
        if isRestoring {
            await withCheckedContinuation { continuation in
                restoreWaiters.append(continuation)
            }
            return
        }
        isRestoring = true
        defer {
            isRestoring = false
            restoreWaiters.forEach { $0.resume() }
            restoreWaiters.removeAll()
        }

        let restored: ActiveJourneySession?
        do {
            restored = try await store.load()
        } catch {
            await store.clear()
            return
        }
        guard let restored, session == nil else { return }
        referenceDate = now()
        guard !ActiveJourneyRules.isExpired(restored.journey, at: referenceDate) else {
            await store.clear()
            return
        }

        session = restored
        alternative = nil
        arrival = nil
        recalculationState = .idle
        requiresResume = true
        evaluateProgress(at: referenceDate)
        startTimeMonitoring()
    }

    func resume() async {
        guard let session else { return }
        referenceDate = now()
        guard !ActiveJourneyRules.isExpired(session.journey, at: referenceDate) else {
            await expireJourney()
            return
        }

        requiresResume = false
        evaluateProgress(at: referenceDate)
        startTimeMonitoring()
        if session.isTrackingStarted {
            startLocationTracking(
                allowsBackgroundUpdates: session.allowsBackgroundTracking
            )
        }
        await persist()
        if session.isTrackingStarted {
            await journeyNotificationManager.registerActiveJourney(session.journey)
        }
        await startActivity()
    }

    func sceneBecameActive() async {
        guard session != nil else {
            await restore()
            return
        }

        referenceDate = now()
        guard let session, !ActiveJourneyRules.isExpired(session.journey, at: referenceDate) else {
            await expireJourney()
            return
        }
        guard !requiresResume else {
            startTimeMonitoring()
            return
        }

        evaluateProgress(at: referenceDate)
        startTimeMonitoring()
        if session.isTrackingStarted {
            await journeyNotificationManager.registerActiveJourney(session.journey)
            startLocationTracking(
                allowsBackgroundUpdates: session.allowsBackgroundTracking
            )
        }
        await persist()
        await updateActivity()
    }

    func moveToPreviousSection() async {
        guard var session else { return }
        session.currentSectionIndex = max(0, session.currentSectionIndex - 1)
        session.manualOverrideUntil = now().addingTimeInterval(
            ActiveJourneyRules.standardMonitoringInterval
        )
        self.session = session
        referenceDate = now()
        await persist()
        await updateActivity()
    }

    func moveToNextSection() async {
        guard var session else { return }
        session.currentSectionIndex = min(
            max(0, session.journey.sections.count - 1),
            session.currentSectionIndex + 1
        )
        session.manualOverrideUntil = now().addingTimeInterval(
            ActiveJourneyRules.standardMonitoringInterval
        )
        self.session = session
        referenceDate = now()
        await persist()
        await updateActivity()
    }

    func checkForAlternative() {
        scheduleRecalculation(force: true)
    }

    func acceptBestAlternative() async {
        guard let alternative else { return }
        await accept(alternative.journey, source: alternative.source)
    }

    func acceptAlternative(_ journey: Journey) async {
        guard let alternative,
              alternative.journeys.contains(where: { $0.id == journey.id }) else { return }
        await accept(journey, source: alternative.source)
    }

    func dismissAlternative() {
        alternative = nil
    }

    func finishJourney() async {
        guard let session else { return }
        let finishedAt = now()
        referenceDate = finishedAt
        arrival = JourneyArrival(
            journeyID: session.journey.id,
            destinationName: session.destination.name,
            arrivedAt: finishedAt
        )
        await activityManager.end(
            journeyID: session.journey.id,
            finalState: activityState(isArrived: true),
            dismissAt: finishedAt.addingTimeInterval(60)
        )
        await journeyNotificationManager.unregisterActiveJourney(session.journey)
        await clearSession()
    }

    func cancelJourney() async {
        guard let session else { return }
        let stoppedAt = now()
        await activityManager.end(
            journeyID: session.journey.id,
            finalState: terminalActivityState(
                title: "Trajet arrêté",
                session: session
            ),
            dismissAt: stoppedAt
        )
        await journeyNotificationManager.unregisterActiveJourney(session.journey)
        arrival = nil
        await clearSession()
    }

    func completeArrival() {
        arrival = nil
    }

    /// Applies a same-identity schedule revision without restarting guidance.
    /// Position, tracking, manual progress and the existing Live Activity all
    /// remain attached to the running session.
    func applyDepartureRevision(_ journey: Journey) async {
        guard var current = session, current.journey.id == journey.id else { return }
        let currentSectionID = current.currentSection?.id
        current.journey = journey
        if let currentSectionID,
           let revisedIndex = journey.sections.firstIndex(where: { $0.id == currentSectionID }) {
            current.currentSectionIndex = revisedIndex
        } else {
            current.currentSectionIndex = ActiveJourneyRules.sectionIndex(in: journey, at: now())
        }
        session = current
        referenceDate = now()
        alternative = nil
        recalculationState = .idle
        await persist()
        if current.isTrackingStarted {
            await journeyNotificationManager.registerActiveJourney(journey)
        }
        await updateActivity()
    }

    func receive(_ sample: LocationSample, at date: Date? = nil) async {
        guard var session else { return }
        referenceDate = date ?? now()
        guard !ActiveJourneyRules.isExpired(session.journey, at: referenceDate) else {
            await expireJourney()
            return
        }

        let previousSectionIndex = session.currentSectionIndex
        session.lastCoordinate = sample.coordinate
        session.horizontalAccuracy = sample.horizontalAccuracy
        self.session = session
        evaluateProgress(at: referenceDate)
        let didChangeSection = self.session?.currentSectionIndex != previousSectionIndex

        if ActiveJourneyRules.hasArrived(
            journey: session.journey,
            coordinate: sample.coordinate,
            horizontalAccuracy: sample.horizontalAccuracy,
            now: referenceDate
        ) {
            await finishJourney()
            return
        }

        if didChangeSection {
            await updateActivity()
            if isCurrentConnectionCompromised(at: referenceDate) {
                scheduleRecalculation(force: false)
            }
        }
        await persist()
    }

    private func begin(
        journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        planningPolicy: JourneyPlanningPolicy
    ) async {
        let activatedAt = now()
        let previousSession = session
        referenceDate = activatedAt
        requiresResume = false
        stopTasks()
        locationModel.stopJourneyTracking()

        if let previousSession, previousSession.journey.id != journey.id {
            await journeyNotificationManager.unregisterActiveJourney(previousSession.journey)
            await activityManager.end(
                journeyID: previousSession.journey.id,
                finalState: terminalActivityState(
                    title: "Itinéraire remplacé",
                    session: previousSession
                ),
                dismissAt: activatedAt
            )
        }

        session = ActiveJourneySession(
            journey: journey,
            destination: destination,
            source: source,
            planningPolicy: planningPolicy,
            currentSectionIndex: ActiveJourneyRules.sectionIndex(in: journey, at: activatedAt),
            lastCoordinate: nil,
            horizontalAccuracy: nil,
            manualOverrideUntil: nil,
            isTrackingStarted: false,
            allowsBackgroundTracking: false
        )
        alternative = nil
        arrival = nil
        recalculationState = .idle
        lastAutomaticRecalculationSectionID = nil
        await persist()
        startTimeMonitoring()
        await startActivity()
    }

    private func startLocationTracking(allowsBackgroundUpdates: Bool) {
        locationTask?.cancel()
        let updates = locationModel.startJourneyTracking(
            allowsBackgroundUpdates: allowsBackgroundUpdates
        )
        locationTask = Task { [weak self] in
            for await sample in updates {
                guard !Task.isCancelled, let self else { return }
                await self.receive(sample)
            }
        }
    }

    private func startTimeMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let journey = self?.session?.journey,
                      let currentDate = self?.now() else { return }
                let delay = ActiveJourneyRules.nextMonitoringDelay(in: journey, at: currentDate)
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
                guard !Task.isCancelled, let self else { return }
                await self.monitoringTick()
            }
        }
    }

    private func monitoringTick() async {
        guard let session else { return }
        referenceDate = now()
        guard !ActiveJourneyRules.isExpired(session.journey, at: referenceDate) else {
            await expireJourney()
            return
        }
        guard !requiresResume else { return }

        evaluateProgress(at: referenceDate)
        await persist()
        await updateActivity()
        if isCurrentConnectionCompromised(at: referenceDate) {
            scheduleRecalculation(force: false)
        }
    }

    private func evaluateProgress(at date: Date) {
        guard var session else { return }
        if let override = session.manualOverrideUntil, date < override { return }
        session.manualOverrideUntil = nil

        let timeIndex = ActiveJourneyRules.sectionIndex(in: session.journey, at: date)
        var nextIndex = max(session.currentSectionIndex, timeIndex)
        if let coordinate = session.lastCoordinate,
           let current = session.currentSection,
           let currentSchedule = ActiveJourneyRules.schedule(for: session.journey)
            .first(where: { $0.id == current.id }),
           date >= currentSchedule.startsAt,
           ActiveJourneyRules.distance(from: coordinate, to: current.to.coordinate)
            <= ActiveJourneyRules.arrivalRadius(horizontalAccuracy: session.horizontalAccuracy) {
            nextIndex = min(
                session.journey.sections.count - 1,
                max(nextIndex, session.currentSectionIndex + 1)
            )
        }
        session.currentSectionIndex = max(0, nextIndex)
        self.session = session
    }

    private func scheduleRecalculation(force: Bool) {
        guard let session,
              recalculationTask == nil,
              isConnected else { return }
        guard force || (alternative == nil && recalculationState != .offline) else { return }
        if !force {
            let sectionID = session.currentSection?.id
            guard sectionID != lastAutomaticRecalculationSectionID else { return }
            lastAutomaticRecalculationSectionID = sectionID
        }

        let identifier = UUID()
        recalculationID = identifier
        recalculationTask = Task { [weak self] in
            await self?.recalculate(force: force)
            guard let self, self.recalculationID == identifier else { return }
            self.recalculationTask = nil
            self.recalculationID = nil
        }
    }

    private func recalculate(force: Bool) async {
        guard let session else { return }
        let journeyID = session.journey.id
        guard let coordinate = session.lastCoordinate ?? locationModel.coordinate else {
            recalculationState = .failed(.invalidRequest("Position indisponible"))
            return
        }
        recalculationState = .checking

        var request = JourneyRequest(origin: coordinate, destination: session.destination)
        request.limit = 4
        request.requestedAt = now()
        request.datetimeRepresents = .departure
        request.requiredModes = session.planningPolicy.requiredModes
        request.excludedModes = session.planningPolicy.excludedModes
        request.preferredModes = session.planningPolicy.preferredModes
        request.requiresAccessibleStations = session.planningPolicy.requiresAccessibleStations

        do {
            let result = try await journeyRepository.plan(request)
            try Task.checkCancellation()
            guard self.session?.journey.id == journeyID else { return }
            guard result.status == .ready else {
                alternative = nil
                recalculationState = result.status == .noRoute
                    ? .noRoute
                    : .failed(.unavailable)
                await updateActivity()
                return
            }

            let candidates = result.journeys
                .filter { $0.id != journeyID }
                .sorted { $0.arrivalAt < $1.arrivalAt }
            guard !candidates.isEmpty else {
                alternative = nil
                recalculationState = .noRoute
                await updateActivity()
                return
            }

            if force || isCurrentConnectionCompromised(at: referenceDate) {
                alternative = ActiveJourneyAlternative(
                    journeys: candidates,
                    source: result.source,
                    currentArrivalAt: session.journey.arrivalAt
                )
            }
            recalculationState = .idle
            await updateActivity()
        } catch is CancellationError {
            return
        } catch {
            guard self.session?.journey.id == journeyID else { return }
            let error = error.via
            recalculationState = error == .transport ? .offline : .failed(error)
            await updateActivity()
        }
    }

    private func connectivityChanged(_ isConnected: Bool) {
        self.isConnected = isConnected
        if isConnected {
            if recalculationState == .offline {
                recalculationState = .idle
            }
        } else {
            recalculationTask?.cancel()
            recalculationTask = nil
            recalculationID = nil
            lastAutomaticRecalculationSectionID = nil
            recalculationState = .offline
        }
        Task { [weak self] in
            await self?.updateActivity()
        }
    }

    private func isCurrentConnectionCompromised(at date: Date) -> Bool {
        guard let session, let coordinate = session.lastCoordinate else { return false }
        let schedules = ActiveJourneyRules.schedule(for: session.journey)
        guard schedules.indices.contains(session.currentSectionIndex) else { return false }
        return ActiveJourneyRules.isConnectionCompromised(
            schedule: schedules[session.currentSectionIndex],
            coordinate: coordinate,
            now: date
        )
    }

    private func accept(_ journey: Journey, source: JourneyResult.Source?) async {
        guard let previous = session else { return }
        let acceptedAt = now()
        session = ActiveJourneySession(
            journey: journey,
            destination: previous.destination,
            source: source,
            planningPolicy: previous.planningPolicy,
            currentSectionIndex: ActiveJourneyRules.sectionIndex(in: journey, at: acceptedAt),
            lastCoordinate: previous.lastCoordinate,
            horizontalAccuracy: previous.horizontalAccuracy,
            manualOverrideUntil: nil,
            isTrackingStarted: previous.isTrackingStarted,
            allowsBackgroundTracking: previous.allowsBackgroundTracking
        )
        referenceDate = acceptedAt
        alternative = nil
        recalculationState = .idle
        lastAutomaticRecalculationSectionID = nil

        await activityManager.end(
            journeyID: previous.journey.id,
            finalState: terminalActivityState(
                title: "Itinéraire remplacé",
                session: previous
            ),
            dismissAt: acceptedAt
        )
        await journeyNotificationManager.unregisterActiveJourney(previous.journey)
        await persist()
        if session?.isTrackingStarted == true {
            await journeyNotificationManager.registerActiveJourney(journey)
        }
        await startActivity()
    }

    private func expireJourney() async {
        guard let session else { return }
        let expiredAt = now()
        await activityManager.end(
            journeyID: session.journey.id,
            finalState: terminalActivityState(
                title: "Trajet terminé",
                session: session
            ),
            dismissAt: expiredAt
        )
        await journeyNotificationManager.unregisterActiveJourney(session.journey)
        arrival = nil
        await clearSession()
    }

    private func clearSession() async {
        stopTasks()
        locationModel.stopJourneyTracking()
        session = nil
        alternative = nil
        requiresResume = false
        recalculationState = .idle
        lastAutomaticRecalculationSectionID = nil
        await store.clear()
    }

    private func stopTasks() {
        locationTask?.cancel()
        monitoringTask?.cancel()
        recalculationTask?.cancel()
        locationTask = nil
        monitoringTask = nil
        recalculationTask = nil
        recalculationID = nil
    }

    private func persist() async {
        guard let session else { return }
        var persistedSession = session
        persistedSession.lastCoordinate = nil
        persistedSession.horizontalAccuracy = nil
        try? await store.save(persistedSession)
    }

    private func instruction(at index: Int?) -> ActiveJourneyInstruction? {
        guard let session, let index,
              session.journey.sections.indices.contains(index) else { return nil }
        let section = session.journey.sections[index]
        let title: String
        let detail: String?

        switch section.kind {
        case .walk:
            title = "Marchez jusqu’à \(section.to.name)"
            detail = section.durationSeconds > 0
                ? JourneyFormatting.duration(section.durationSeconds)
                : nil
        case .wait:
            title = "Patientez à \(section.from.name)"
            detail = section.durationSeconds > 0
                ? JourneyFormatting.duration(section.durationSeconds)
                : nil
        case .transfer:
            title = "Rejoignez \(section.to.name)"
            detail = section.durationSeconds > 0
                ? "Correspondance · \(JourneyFormatting.duration(section.durationSeconds))"
                : "Correspondance"
        case .transit:
            title = section.route.map { "Prenez \($0.longName)" } ?? "Prenez le transport"
            let direction = section.direction.map { "Direction \($0)" }
            let platform = section.platform.map { "Quai \($0)" }
            // Where to stand comes before where to leave: one is acted on now,
            // on this platform, the other several stops later.
            let car = section.boardingPosition.map { "Voiture \($0.car)/\($0.carCount)" }
            let exit = section.exit.map(JourneyGuidance.exitLabel)
            detail = [direction, platform, car, exit]
                .compactMap { $0 }
                .joined(separator: " · ")
                .nilIfEmpty
        }

        return ActiveJourneyInstruction(
            title: title,
            detail: detail,
            route: section.route,
            startsAt: section.departureAt,
            endsAt: section.arrivalAt,
            stops: section.stops,
            sectionKind: section.kind
        )
    }

    private func startActivity() async {
        guard let session else { return }
        await activityManager.start(
            attributes: JourneyActivityAttributes(
                journeyID: session.journey.id.rawValue
            ),
            state: activityState(isArrived: false),
            staleAt: nextStaleDate
        )
    }

    private func activityState(isArrived: Bool) -> JourneyActivityAttributes.ContentState {
        let phaseTitle: String
        switch phase {
        case .scheduled(let interval):
            phaseTitle = "Départ dans \(JourneyFormatting.countdown(interval))"
        case .underway:
            phaseTitle = isArrived ? "Vous êtes arrivé" : "En route"
        }
        // The lock screen says the same sentence as the guidance header and the
        // tab bar accessory, from the same derivation.
        let headline = guidanceHeadline
        let currentProgress = progress
        return JourneyActivityAttributes.ContentState(
            phaseTitle: isArrived ? "Vous êtes arrivé" : phaseTitle,
            instructionTitle: isArrived ? destinationName : headline?.title ?? destinationName,
            instructionDetail: isArrived ? nil : headline?.detail,
            nextAction: isArrived ? nil : nextInstruction?.title,
            line: isArrived ? nil : activityLine,
            nextLine: isArrived ? nil : activityNextLine,
            arrivalAt: journey?.arrivalAt ?? referenceDate,
            isOffline: isOffline,
            isArrived: isArrived,
            progressFraction: isArrived ? 1 : currentProgress?.overallFraction ?? 0,
            stopsRemaining: isArrived ? nil : headline?.stopsUntilAlighting,
            alightStopName: isArrived ? nil : headline?.alightStopName
        )
    }

    /// The line the Live Activity puts forward: the one being ridden, or the
    /// one the current walk or wait leads to, so the badge survives the legs
    /// that have no route of their own.
    private var activityLine: JourneyActivityAttributes.LineBadge? {
        (guidanceHeadline?.route ?? upcomingRoute).map { JourneyActivityAttributes.LineBadge(route: $0) }
    }

    /// Only worth a badge on the "Ensuite" line when it is not the line already
    /// shown for the current step.
    private var activityNextLine: JourneyActivityAttributes.LineBadge? {
        guard let route = nextInstruction?.route else { return nil }
        let badge = JourneyActivityAttributes.LineBadge(route: route)
        return badge == activityLine ? nil : badge
    }

    private var upcomingRoute: JourneyRoute? {
        guard let session else { return nil }
        let sections = session.journey.sections
        let index = max(0, session.currentSectionIndex)
        guard sections.indices.contains(index) else { return nil }
        return sections[index...].first { $0.kind == .transit }?.route
    }

    private func terminalActivityState(
        title: String,
        session: ActiveJourneySession
    ) -> JourneyActivityAttributes.ContentState {
        JourneyActivityAttributes.ContentState(
            phaseTitle: title,
            instructionTitle: session.destination.name,
            instructionDetail: nil,
            nextAction: nil,
            line: nil,
            nextLine: nil,
            arrivalAt: session.journey.arrivalAt,
            isOffline: false,
            isArrived: false,
            progressFraction: 1,
            stopsRemaining: nil,
            alightStopName: nil
        )
    }

    private func updateActivity() async {
        guard let session else { return }
        await activityManager.update(
            journeyID: session.journey.id,
            state: activityState(isArrived: false),
            staleAt: nextStaleDate
        )
    }

    private var nextStaleDate: Date {
        let interval = journey.map {
            ActiveJourneyRules.nextMonitoringDelay(in: $0, at: referenceDate)
        } ?? ActiveJourneyRules.standardMonitoringInterval
        return referenceDate.addingTimeInterval(max(45, interval * 1.5))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension JourneyActivityAttributes.LineBadge {
    init(route: JourneyRoute) {
        self.init(
            shortName: route.shortName,
            colorHex: route.colorHex,
            textColorHex: route.textColorHex
        )
    }
}
