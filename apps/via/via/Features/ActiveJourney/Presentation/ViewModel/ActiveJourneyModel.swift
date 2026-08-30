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
        journey.map {
            JourneyMapPresentation(journey: $0, includesOrigin: !isTracking)
        }
    }
    var highlightedSectionID: String? {
        guard let session else { return nil }
        return session.journey.sections.indices.contains(session.currentSectionIndex)
            ? session.journey.sections[session.currentSectionIndex].id
            : nil
    }

    /// The one sentence describing what to do now, shared by the guidance
    /// header, the tab bar accessory and the Live Activity.
    var guidanceHeadline: JourneyGuidanceHeadline? { guidanceHeadline(at: referenceDate) }

    func guidanceHeadline(at date: Date) -> JourneyGuidanceHeadline? {
        guard let session else { return nil }
        return JourneyGuidance.headline(
            journey: session.journey,
            schedule: ActiveJourneyRules.schedule(for: session.journey),
            sectionIndex: session.currentSectionIndex,
            at: date,
            isPaused: requiresResume,
            liveStopProgress: liveStopProgress
        )
    }
    var destinationName: String { session?.destination.name ?? "Destination" }
    var phase: ActiveJourneyPhase { phase(at: referenceDate) }

    /// The current step is now described by `guidanceHeadline`; only the
    /// look-ahead survives, for the Live Activity's "Ensuite" line.
    var nextInstruction: ActiveJourneyInstruction? {
        guard let session else { return nil }
        return JourneyActivityPresentation.nextInstruction(in: session)
    }

    var isOffline: Bool { !isConnected || recalculationState == .offline }
    var canRecalculate: Bool { isConnected }
    var hasBackgroundLocationAuthorization: Bool {
        locationModel.backgroundAuthorizationGranted
    }
    var expectsBackgroundTracking: Bool {
        session?.allowsBackgroundTracking == true
    }
    var hasLiveLocationFix: Bool { isLocationUsable(at: referenceDate) }
    var currentSectionIndex: Int? { session?.currentSectionIndex }
    var liveStopProgress: JourneyStopProgress? {
        guard hasLiveLocationFix,
              let session,
              let coordinate = session.lastCoordinate,
              session.journey.sections.indices.contains(session.currentSectionIndex),
              let section = session.currentSection,
              section.kind == .transit else {
            return nil
        }

        let stops = JourneyTimeline.transitStops(
            in: session.journey,
            sectionIndex: session.currentSectionIndex
        )
        return JourneyLocationMatcher.stopProgress(
            sectionID: section.id,
            stops: stops,
            path: session.journey.path(at: session.currentSectionIndex),
            to: coordinate,
            horizontalAccuracy: session.horizontalAccuracy
        )
    }

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

        let coordinate = await locationModel.requestFreshLocation(timeout: .seconds(10))
        guard var current = self.session, current.journey.id == journeyID else { return }
        referenceDate = now()
        current.lastCoordinate = coordinate
        current.horizontalAccuracy = nil
        current.lastLocationAt = coordinate == nil ? nil : referenceDate
        self.session = current
        updateSectionFromLocation(at: referenceDate)

        startLocationTracking(allowsBackgroundUpdates: allowsBackgroundTracking)
        startTimeMonitoring()
        await persist()
        await journeyNotificationManager.registerActiveJourney(
            session.journey,
            activationID: session.activationID
        )
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
            _ = await store.clear(ifActivationID: restored.activationID)
            return
        }

        session = restored
        alternative = nil
        arrival = nil
        recalculationState = .idle
        requiresResume = true
        updateSectionFromLocation(at: referenceDate)
        startTimeMonitoring()
        await updateActivity()
    }

    func resume() async {
        guard let session else { return }
        referenceDate = now()
        guard !ActiveJourneyRules.isExpired(session.journey, at: referenceDate) else {
            await expireJourney()
            return
        }

        requiresResume = false
        updateSectionFromLocation(at: referenceDate)
        startTimeMonitoring()
        if session.isTrackingStarted {
            startLocationTracking(
                allowsBackgroundUpdates: session.allowsBackgroundTracking
            )
        }
        await persist()
        if session.isTrackingStarted {
            await journeyNotificationManager.registerActiveJourney(
                session.journey,
                activationID: session.activationID
            )
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

        updateSectionFromLocation(at: referenceDate)
        startTimeMonitoring()
        if session.isTrackingStarted {
            await journeyNotificationManager.registerActiveJourney(
                session.journey,
                activationID: session.activationID
            )
            startLocationTracking(
                allowsBackgroundUpdates: session.allowsBackgroundTracking
            )
        }
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
        guard let captured = session else { return }
        let finishedAt = now()
        referenceDate = finishedAt
        let finalArrival = JourneyArrival(
            journeyID: captured.journey.id,
            destinationName: captured.destination.name,
            arrivedAt: finishedAt
        )
        let finalState = activityState(for: captured, isArrived: true)
        detachSession(captured, arrival: finalArrival)
        _ = await store.clear(ifActivationID: captured.activationID)
        await activityManager.end(
            journeyID: captured.journey.id,
            finalState: finalState,
            dismissAt: finishedAt.addingTimeInterval(60)
        )
        await journeyNotificationManager.unregisterActiveJourney(
            captured.journey,
            activationID: captured.activationID
        )
    }

    func cancelJourney() async {
        guard let captured = session else { return }
        let stoppedAt = now()
        let finalState = terminalActivityState(
            title: "Trajet arrêté",
            session: captured
        )
        detachSession(captured, arrival: nil)
        _ = await store.clear(ifActivationID: captured.activationID)
        await activityManager.end(
            journeyID: captured.journey.id,
            finalState: finalState,
            dismissAt: stoppedAt
        )
        await journeyNotificationManager.unregisterActiveJourney(
            captured.journey,
            activationID: captured.activationID
        )
    }

    func completeArrival() {
        arrival = nil
    }

    /// Applies a same-identity schedule revision without restarting guidance.
    /// The current section and native location fix remain attached to the
    /// running session.
    func applyDepartureRevision(_ journey: Journey) async {
        guard var current = session, current.journey.id == journey.id else { return }
        let currentSectionID = current.currentSection?.id
        current.journey = journey
        if let currentSectionID,
           let revisedIndex = journey.sections.firstIndex(where: { $0.id == currentSectionID }) {
            current.currentSectionIndex = revisedIndex
        } else {
            current.currentSectionIndex = min(
                current.currentSectionIndex,
                max(0, journey.sections.count - 1)
            )
        }
        session = current
        referenceDate = now()
        alternative = nil
        recalculationState = .idle
        await persist()
        if current.isTrackingStarted {
            await journeyNotificationManager.registerActiveJourney(
                journey,
                activationID: current.activationID
            )
        }
        await updateActivity()
    }

    func receive(_ sample: LocationSample, at date: Date? = nil) async {
        guard var session else { return }
        let previousStopProgress = liveStopProgress
        referenceDate = date ?? now()
        guard !ActiveJourneyRules.isExpired(session.journey, at: referenceDate) else {
            await expireJourney()
            return
        }

        let previousSectionIndex = session.currentSectionIndex
        let wasLiveLocation = isLocationUsable(at: referenceDate)
        // Core Location can deliver a buffered point after a newer one. Never
        // let that out-of-order sample make a previously fresh fix look stale.
        let isNewSample = sample.recordedAt >= (session.lastLocationAt ?? .distantPast)
        if isNewSample || session.lastCoordinate == nil {
            session.lastCoordinate = sample.coordinate
            session.horizontalAccuracy = sample.horizontalAccuracy
            session.lastLocationAt = sample.recordedAt
        }
        self.session = session
        updateSectionFromLocation(at: referenceDate)
        let didChangeSection = self.session?.currentSectionIndex != previousSectionIndex
        let didChangeLocationMode = wasLiveLocation != isLocationUsable(at: referenceDate)
        let currentStopProgress = liveStopProgress
        let didChangeStopProgress = currentStopProgress != previousStopProgress
        let alightingAlert = isNewSample && isLocationUsable(at: referenceDate)
            ? consumeAlightingAlert(
                for: currentStopProgress,
                coordinate: sample.coordinate
            )
            : nil

        // A buffered point can still be useful for diagnostics, but it must
        // not finish the journey after a newer fix.
        if isNewSample,
           isLocationUsable(at: referenceDate),
           ActiveJourneyRules.hasArrived(
               journey: session.journey,
               coordinate: sample.coordinate,
               horizontalAccuracy: sample.horizontalAccuracy,
               now: referenceDate
           ) {
            if let alightingAlert {
                await updateActivity(alert: alightingAlert)
            }
            await finishJourney()
            return
        }

        if didChangeSection || didChangeLocationMode || didChangeStopProgress || alightingAlert != nil {
            await updateActivity(alert: alightingAlert)
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
            await journeyNotificationManager.unregisterActiveJourney(
                previousSession.journey,
                activationID: previousSession.activationID
            )
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
            // No timetable-based position: until Core Location confirms a
            // section, guidance stays at the journey's first step.
            currentSectionIndex: 0,
            lastCoordinate: nil,
            horizontalAccuracy: nil,
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

        await persist()
        await updateActivity()
        if isCurrentConnectionCompromised(at: referenceDate) {
            scheduleRecalculation(force: false)
        }
    }

    private func updateSectionFromLocation(at date: Date) {
        guard var session else { return }
        guard isLocationUsable(at: date),
              let coordinate = session.lastCoordinate else {
            self.session = session
            return
        }

        let schedule = ActiveJourneyRules.schedule(for: session.journey)
        if let sectionIndex = JourneyLocationMatcher.nearestSectionIndex(
            schedule: schedule,
            to: coordinate,
            horizontalAccuracy: session.horizontalAccuracy
        ) {
            session.currentSectionIndex = sectionIndex
        }
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
        guard isLocationUsable(at: referenceDate),
              let coordinate = session.lastCoordinate else {
            recalculationState = .failed(.invalidRequest("Position indisponible"))
            return
        }
        recalculationState = .checking

        let request = JourneyRequest(
            origin: coordinate,
            destination: session.destination,
            policy: session.planningPolicy,
            requestedAt: now(),
            datetimeRepresents: .departure
        )

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
            referenceDate = now()
            if session?.isTrackingStarted == true {
                locationModel.refreshJourneyTracking()
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
        guard isLocationUsable(at: date),
              let session,
              let coordinate = session.lastCoordinate else { return false }
        let schedules = ActiveJourneyRules.schedule(for: session.journey)
        guard schedules.indices.contains(session.currentSectionIndex) else { return false }
        return ActiveJourneyRules.isConnectionCompromised(
            schedule: schedules[session.currentSectionIndex],
            coordinate: coordinate,
            now: date
        )
    }

    private func isLocationUsable(at date: Date) -> Bool {
        guard let session,
              session.isTrackingStarted,
              session.lastCoordinate != nil,
              let recordedAt = session.lastLocationAt else {
            return false
        }

        let age = date.timeIntervalSince(recordedAt)
        return age >= -5 && age <= ActiveJourneyRules.locationFreshnessInterval
    }

    private func accept(_ journey: Journey, source: JourneyResult.Source?) async {
        guard let previous = session else { return }
        let acceptedAt = now()
        session = ActiveJourneySession(
            journey: journey,
            destination: previous.destination,
            source: source,
            planningPolicy: previous.planningPolicy,
            currentSectionIndex: min(
                previous.currentSectionIndex,
                max(0, journey.sections.count - 1)
            ),
            lastCoordinate: previous.lastCoordinate,
            horizontalAccuracy: previous.horizontalAccuracy,
            lastLocationAt: previous.lastLocationAt,
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
        await journeyNotificationManager.unregisterActiveJourney(
            previous.journey,
            activationID: previous.activationID
        )
        await persist()
        if session?.isTrackingStarted == true {
            if let current = session {
                await journeyNotificationManager.registerActiveJourney(
                    journey,
                    activationID: current.activationID
                )
            }
        }
        await startActivity()
    }

    private func expireJourney() async {
        guard let captured = session else { return }
        let expiredAt = now()
        let finalState = terminalActivityState(
            title: "Trajet terminé",
            session: captured
        )
        detachSession(captured, arrival: nil)
        _ = await store.clear(ifActivationID: captured.activationID)
        await activityManager.end(
            journeyID: captured.journey.id,
            finalState: finalState,
            dismissAt: expiredAt
        )
        await journeyNotificationManager.unregisterActiveJourney(
            captured.journey,
            activationID: captured.activationID
        )
    }

    private func detachSession(_ captured: ActiveJourneySession, arrival: JourneyArrival?) {
        _ = captured
        stopTasks()
        locationModel.stopJourneyTracking()
        session = nil
        alternative = nil
        self.arrival = arrival
        requiresResume = false
        recalculationState = .idle
        lastAutomaticRecalculationSectionID = nil
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
        persistedSession.lastLocationAt = nil
        try? await store.save(persistedSession)
    }

    private func startActivity() async {
        guard let session else { return }
        await activityManager.start(
            attributes: JourneyActivityAttributes(
                journeyID: session.journey.id.rawValue
            ),
            state: activityState(for: session, isArrived: false),
            staleAt: JourneyActivityPresentation.staleDate(
                for: session.journey,
                at: referenceDate
            )
        )
    }

    /// The whole payload — wording included — comes from
    /// `JourneyActivityPresentation`; the model only supplies its state.
    private func activityState(
        for session: ActiveJourneySession,
        isArrived: Bool
    ) -> JourneyActivityAttributes.ContentState {
        JourneyActivityPresentation.contentState(
            session: session,
            isArrived: isArrived,
            requiresResume: requiresResume,
            isOffline: isOffline,
            at: referenceDate,
            liveStopProgress: liveStopProgress
        )
    }

    private func terminalActivityState(
        title: String,
        session: ActiveJourneySession
    ) -> JourneyActivityAttributes.ContentState {
        JourneyActivityPresentation.terminal(title: title, session: session)
    }

    private func updateActivity(alert: JourneyActivityAlert? = nil) async {
        guard let session else { return }
        await activityManager.update(
            journeyID: session.journey.id,
            state: activityState(for: session, isArrived: false),
            staleAt: JourneyActivityPresentation.staleDate(
                for: session.journey,
                at: referenceDate
            ),
            alert: alert
        )
    }

    /// Marks the section before returning its alert so every subsequent GPS
    /// sample — including jitter around the same platform — is silent.
    private func consumeAlightingAlert(
        for progress: JourneyStopProgress?,
        coordinate: GeoCoordinate
    ) -> JourneyActivityAlert? {
        guard var session,
              let progress,
              progress.sectionID == session.currentSection?.id,
              !session.alertedAlightingSectionIDs.contains(progress.sectionID),
              JourneyLocationMatcher.shouldAlertForAlighting(
                progress: progress,
                coordinate: coordinate
              ),
              let alert = JourneyActivityPresentation.alightingAlert(for: progress)
        else { return nil }

        session.alertedAlightingSectionIDs.insert(progress.sectionID)
        self.session = session
        return alert
    }
}
