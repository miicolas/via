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

    @ObservationIgnored private let locationModel: LocationModel
    @ObservationIgnored private let journeyRepository: any JourneyRepository
    @ObservationIgnored private let store: any ActiveJourneyStore
    @ObservationIgnored private let activityManager: any JourneyActivityManaging
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var locationTask: Task<Void, Never>?
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?
    @ObservationIgnored private var recalculationTask: Task<Void, Never>?

    init(
        locationModel: LocationModel,
        journeyRepository: any JourneyRepository,
        store: any ActiveJourneyStore = InMemoryActiveJourneyStore(),
        activityManager: any JourneyActivityManaging = NoOpJourneyActivityManager(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.locationModel = locationModel
        self.journeyRepository = journeyRepository
        self.store = store
        self.activityManager = activityManager
        self.now = now
        referenceDate = now()
    }

    var isActive: Bool { session != nil }
    var journey: Journey? { session?.journey }
    var mapPresentation: JourneyMapPresentation? {
        journey.map { JourneyMapPresentation(journey: $0) }
    }
    var highlightedSectionID: String? { session?.currentSection?.id }
    var destinationName: String { session?.destination.name ?? "Destination" }

    var phase: ActiveJourneyPhase {
        guard let journey else { return .underway }
        let interval = journey.departureAt.timeIntervalSince(referenceDate)
        return interval > 0 ? .scheduled(interval) : .underway
    }

    var currentInstruction: ActiveJourneyInstruction? {
        instruction(at: session?.currentSectionIndex)
    }

    var nextInstruction: ActiveJourneyInstruction? {
        guard let session else { return nil }
        return instruction(at: session.currentSectionIndex + 1)
    }

    var isOffline: Bool {
        recalculationState == .offline
    }

    var hasBackgroundLocationAuthorization: Bool {
        locationModel.backgroundAuthorizationGranted
    }

    var hasLocationFix: Bool {
        session?.lastCoordinate != nil
    }

    func activeJourney() async -> ActiveJourneyContext? {
        guard let session else { return nil }
        return ActiveJourneyContext(
            journeyID: session.journey.id,
            lineID: session.currentSection?.route?.id,
            vehicleID: nil
        )
    }

    func activate(
        journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        requestBackgroundAuthorization: Bool
    ) async {
        if session?.journey.id == journey.id {
            referenceDate = now()
            startMonitoring(requestBackgroundAuthorization: requestBackgroundAuthorization)
            return
        }

        let activatedAt = now()
        referenceDate = activatedAt
        let coordinate = await locationModel.requestFreshLocation()
        session = ActiveJourneySession(
            journey: journey,
            destination: destination,
            source: source,
            currentSectionIndex: ActiveJourneyRules.sectionIndex(in: journey, at: activatedAt),
            lastCoordinate: coordinate,
            horizontalAccuracy: locationModel.latestSample?.horizontalAccuracy,
            manualOverrideUntil: nil
        )
        alternative = nil
        arrival = nil
        recalculationState = .idle
        await persist()
        startMonitoring(requestBackgroundAuthorization: requestBackgroundAuthorization)
        await activityManager.start(
            attributes: activityAttributes(for: journey, destination: destination),
            state: activityState(isArrived: false),
            staleAt: nextStaleDate
        )
    }

    func restore() async {
        guard session == nil else {
            await sceneBecameActive()
            return
        }
        guard let restored = try? await store.load() else { return }

        referenceDate = now()
        guard !ActiveJourneyRules.isExpired(restored.journey, at: referenceDate) else {
            await store.clear()
            return
        }

        session = restored
        alternative = nil
        arrival = nil
        evaluateProgress(at: referenceDate)
        startMonitoring(requestBackgroundAuthorization: false)
        await activityManager.start(
            attributes: activityAttributes(for: restored.journey, destination: restored.destination),
            state: activityState(isArrived: false),
            staleAt: nextStaleDate
        )
    }

    func sceneBecameActive() async {
        guard session != nil else {
            await restore()
            return
        }
        referenceDate = now()
        evaluateProgress(at: referenceDate)
        await persist()
        await updateActivity()
    }

    func moveToPreviousSection() async {
        guard var session else { return }
        session.currentSectionIndex = max(0, session.currentSectionIndex - 1)
        session.manualOverrideUntil = now().addingTimeInterval(ActiveJourneyRules.standardMonitoringInterval)
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
        session.manualOverrideUntil = now().addingTimeInterval(ActiveJourneyRules.standardMonitoringInterval)
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
        let finalState = activityState(isArrived: true)
        await activityManager.end(
            journeyID: session.journey.id,
            finalState: finalState,
            dismissAt: finishedAt.addingTimeInterval(60)
        )
        await clearSession()
    }

    func cancelJourney() async {
        guard let session else { return }
        let finalState = JourneyActivityAttributes.ContentState(
            phaseTitle: "Trajet arrêté",
            instructionTitle: session.destination.name,
            instructionDetail: nil,
            nextAction: nil,
            routeShortName: nil,
            routeColorHex: nil,
            arrivalAt: session.journey.arrivalAt,
            updatedAt: now(),
            isOffline: isOffline,
            isArrived: false
        )
        await activityManager.end(
            journeyID: session.journey.id,
            finalState: finalState,
            dismissAt: now()
        )
        arrival = nil
        await clearSession()
    }

    func completeArrival() {
        arrival = nil
    }

    func receive(_ sample: LocationSample, at date: Date? = nil) async {
        guard var session else { return }
        let previousSectionIndex = session.currentSectionIndex
        referenceDate = date ?? now()
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
        }
        if didChangeSection || isCurrentConnectionCompromised(at: referenceDate) {
            scheduleRecalculation(force: false)
        }
        await persist()
    }

    private func startMonitoring(requestBackgroundAuthorization: Bool) {
        locationTask?.cancel()
        monitoringTask?.cancel()

        let updates = locationModel.startJourneyTracking(
            requestBackgroundAuthorization: requestBackgroundAuthorization
        )
        locationTask = Task { [weak self] in
            for await sample in updates {
                guard !Task.isCancelled, let self else { return }
                await self.receive(sample)
            }
        }

        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let journey = self.session?.journey else { return }
                let interval = ActiveJourneyRules.monitoringInterval(
                    in: journey,
                    at: self.referenceDate
                )
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await self.monitoringTick()
            }
        }
    }

    private func monitoringTick() async {
        guard session != nil else { return }
        referenceDate = now()
        evaluateProgress(at: referenceDate)
        await persist()
        await updateActivity()
        scheduleRecalculation(force: false)
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
            nextIndex = min(session.journey.sections.count - 1, max(nextIndex, session.currentSectionIndex + 1))
        }
        session.currentSectionIndex = max(0, nextIndex)
        self.session = session
    }

    private func scheduleRecalculation(force: Bool) {
        guard recalculationTask == nil,
              session != nil,
              force || !isOffline else { return }
        recalculationTask = Task { [weak self] in
            await self?.recalculate(force: force)
            self?.recalculationTask = nil
        }
    }

    private func recalculate(force: Bool) async {
        guard let session,
              let coordinate = session.lastCoordinate ?? locationModel.coordinate else { return }
        recalculationState = .checking

        var request = JourneyRequest(origin: coordinate, destination: session.destination)
        request.limit = 4
        request.requestedAt = now()
        request.datetimeRepresents = .departure

        do {
            let result = try await journeyRepository.plan(request)
            guard result.status == .ready else {
                recalculationState = .idle
                await updateActivity()
                return
            }
            let candidates = result.journeys
                .filter { $0.id != session.journey.id }
                .sorted { $0.arrivalAt < $1.arrivalAt }
            guard !candidates.isEmpty else {
                alternative = nil
                recalculationState = .idle
                await updateActivity()
                return
            }

            let isCompromised = isCurrentConnectionCompromised(at: referenceDate)
            if force || isCompromised {
                alternative = ActiveJourneyAlternative(
                    journeys: candidates,
                    source: result.source,
                    currentArrivalAt: session.journey.arrivalAt
                )
            }
            recalculationState = .idle
            await updateActivity()
        } catch {
            recalculationState = error.via == .transport ? .offline : .idle
            await updateActivity()
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
        let previousID = previous.journey.id
        let acceptedAt = now()
        session = ActiveJourneySession(
            journey: journey,
            destination: previous.destination,
            source: source,
            currentSectionIndex: ActiveJourneyRules.sectionIndex(in: journey, at: acceptedAt),
            lastCoordinate: previous.lastCoordinate,
            horizontalAccuracy: previous.horizontalAccuracy,
            manualOverrideUntil: nil
        )
        referenceDate = acceptedAt
        alternative = nil

        let endedState = JourneyActivityAttributes.ContentState(
            phaseTitle: "Itinéraire remplacé",
            instructionTitle: previous.destination.name,
            instructionDetail: nil,
            nextAction: nil,
            routeShortName: nil,
            routeColorHex: nil,
            arrivalAt: previous.journey.arrivalAt,
            updatedAt: acceptedAt,
            isOffline: false,
            isArrived: false
        )
        await activityManager.end(
            journeyID: previousID,
            finalState: endedState,
            dismissAt: acceptedAt
        )
        await persist()
        if let session {
            await activityManager.start(
                attributes: activityAttributes(for: journey, destination: session.destination),
                state: activityState(isArrived: false),
                staleAt: nextStaleDate
            )
        }
    }

    private func clearSession() async {
        locationTask?.cancel()
        monitoringTask?.cancel()
        recalculationTask?.cancel()
        locationTask = nil
        monitoringTask = nil
        recalculationTask = nil
        locationModel.stopJourneyTracking()
        session = nil
        alternative = nil
        recalculationState = .idle
        await store.clear()
    }

    private func persist() async {
        guard let session else { return }
        try? await store.save(session)
    }

    private func instruction(at index: Int?) -> ActiveJourneyInstruction? {
        guard let session, let index,
              session.journey.sections.indices.contains(index) else { return nil }
        let schedule = ActiveJourneyRules.schedule(for: session.journey)[index]
        let section = schedule.section
        let title: String
        let detail: String?

        switch section.kind {
        case .walk:
            title = "Marchez jusqu’à \(section.to.name)"
            detail = durationText(section.durationSeconds)
        case .wait:
            title = "Patientez à \(section.from.name)"
            detail = durationText(section.durationSeconds)
        case .transfer:
            title = "Rejoignez \(section.to.name)"
            detail = "Correspondance · \(durationText(section.durationSeconds))"
        case .transit:
            title = section.route.map { "Prenez \($0.longName)" } ?? "Prenez le transport"
            let direction = section.direction.map { "Direction \($0)" }
            let platform = section.platform.map { "Quai \($0)" }
            detail = [direction, platform].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
        }

        return ActiveJourneyInstruction(
            title: title,
            detail: detail,
            route: section.route,
            startsAt: schedule.startsAt,
            endsAt: schedule.endsAt,
            sectionKind: section.kind
        )
    }

    private func activityAttributes(
        for journey: Journey,
        destination: JourneyDestination
    ) -> JourneyActivityAttributes {
        JourneyActivityAttributes(
            journeyID: journey.id.rawValue,
            destinationName: destination.name
        )
    }

    private func activityState(isArrived: Bool) -> JourneyActivityAttributes.ContentState {
        let instruction = currentInstruction
        let phaseTitle: String
        switch phase {
        case .scheduled(let interval):
            phaseTitle = "Départ dans \(max(1, Int(ceil(interval / 60)))) min"
        case .underway:
            phaseTitle = isArrived ? "Vous êtes arrivé" : "En route"
        }
        return JourneyActivityAttributes.ContentState(
            phaseTitle: isArrived ? "Vous êtes arrivé" : phaseTitle,
            instructionTitle: isArrived ? destinationName : instruction?.title ?? destinationName,
            instructionDetail: isArrived ? nil : instruction?.detail,
            nextAction: isArrived ? nil : nextInstruction?.title,
            routeShortName: isArrived ? nil : instruction?.route?.shortName,
            routeColorHex: isArrived ? nil : instruction?.route?.colorHex,
            arrivalAt: journey?.arrivalAt ?? referenceDate,
            updatedAt: referenceDate,
            isOffline: isOffline,
            isArrived: isArrived
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
        referenceDate.addingTimeInterval(ActiveJourneyRules.standardMonitoringInterval * 1.5)
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(1, Int(ceil(Double(seconds) / 60)))
        return "\(minutes) min"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
