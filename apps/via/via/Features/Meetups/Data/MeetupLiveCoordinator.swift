import Foundation
import Observation

enum MeetupLivePublishingPolicy {
    static let minimumInterval: TimeInterval = 5
    static let heartbeatInterval: TimeInterval = 15
    static let significantDistanceMeters = 15.0

    static func publicationDelay(after previous: Date?, now: Date) -> TimeInterval {
        guard let previous else { return 0 }
        return max(0, minimumInterval - now.timeIntervalSince(previous))
    }

    static func shouldPublish(
        sample: LocationSample,
        after previous: LocationSample?,
        publishedAt: Date?
    ) -> Bool {
        guard let previous, let publishedAt else { return true }
        guard sample.recordedAt.timeIntervalSince(publishedAt) >= minimumInterval else {
            return false
        }
        return sample.coordinate.metersAway(from: previous.coordinate) >= significantDistanceMeters
            || sample.horizontalAccuracy != previous.horizontalAccuracy
    }

    static func isFresh(sample: LocationSample, now: Date) -> Bool {
        let age = now.timeIntervalSince(sample.recordedAt)
        return age >= -5 && age <= ActiveJourneyRules.locationFreshnessInterval
    }
}

@MainActor
@Observable
final class MeetupLiveCoordinator: MeetupLiveSharing {
    private(set) var activeMeetup: Meetup?
    private(set) var snapshot: MeetupLiveSnapshot?
    private(set) var preciseLocations: [String: MeetupPreciseLocation] = [:]
    private(set) var error: ViaError?

    @ObservationIgnored private let transport: any MeetupLiveTransport
    @ObservationIgnored private let cryptography: any MeetupCryptography
    @ObservationIgnored private let locationModel: LocationModel
    @ObservationIgnored private let activityManager: any MeetupActivityManaging
    @ObservationIgnored private let precisePresenceEnabled: @Sendable () -> Bool
    @ObservationIgnored private var locationTask: Task<Void, Never>?
    @ObservationIgnored private var heartbeatTask: Task<Void, Never>?
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    @ObservationIgnored private var deferredPublishTask: Task<Void, Never>?
    @ObservationIgnored private var lastPublishedSample: LocationSample?
    @ObservationIgnored private var lastPublishedAt: Date?
    @ObservationIgnored private var lastLivePublishedAt: Date?
    @ObservationIgnored private var pendingPresenceSample: LocationSample?
    @ObservationIgnored private var lastResolvedSampleAt: Date?
    @ObservationIgnored private var trackingStartedAt: Date?
    @ObservationIgnored private var progress: MeetupProgress?
    @ObservationIgnored private var pollingMeetupID: String?
    @ObservationIgnored private var activityEnabled = false
    @ObservationIgnored private var usesLocationTracking = false

    init(
        transport: any MeetupLiveTransport,
        cryptography: any MeetupCryptography,
        locationModel: LocationModel,
        activityManager: any MeetupActivityManaging = NoOpMeetupActivityManager(),
        precisePresenceEnabled: @escaping @Sendable () -> Bool = {
            MeetupFeatureFlags.precisePresenceEnabled
        }
    ) {
        self.transport = transport
        self.cryptography = cryptography
        self.locationModel = locationModel
        self.activityManager = activityManager
        self.precisePresenceEnabled = precisePresenceEnabled
    }

    var isActive: Bool { activeMeetup != nil }

    func start(_ meetup: Meetup, includesLiveActivity: Bool = false) async {
        guard meetup.targetArrivalAt.addingTimeInterval(2 * 60 * 60) > .now else { return }
        await stop(publishing: nil)
        activeMeetup = meetup
        activityEnabled = includesLiveActivity
        error = nil
        try? await transport.synchronizeGroupKey(for: meetup)
        progress = initialProgress(for: meetup)
        startExpiryTimer(for: meetup)
        if includesLiveActivity {
            await activityManager.start(
                attributes: MeetupActivityAttributes(
                    meetupID: meetup.id,
                    destinationName: meetup.destination.name
                ),
                state: activityState(for: meetup),
                staleAt: .now.addingTimeInterval(60)
            )
        }

        switch meetup.currentParticipant?.shareLevel ?? .off {
        case .off:
            return
        case .progressOnly, .positionAndProgress:
            await publish(progress: progress, presence: nil)
            startLocationTracking()
            startHeartbeat()
        }
    }

    func updateProgress(_ next: MeetupProgress) async {
        progress = next
        await updateActivity()
        guard activeMeetup?.currentParticipant?.shareLevel != .off else {
            if next.status == .missed || next.status == .arrived {
                await publish(progress: next, presence: nil)
            }
            if next.status == .arrived { await stop(publishing: nil) }
            return
        }
        await publish(progress: next, presence: nil)
        if next.status == .arrived { await stop(publishing: nil) }
    }

    func applyShareLevelChange(_ meetup: Meetup) async {
        guard activeMeetup?.id == meetup.id else { return }
        activeMeetup = meetup

        switch meetup.currentParticipant?.shareLevel ?? .off {
        case .off:
            await stop(publishing: nil)
        case .progressOnly:
            startLocationTracking()
            await publish(progress: progress, presence: nil)
            startHeartbeat()
        case .positionAndProgress:
            startLocationTracking()
            startHeartbeat()
        }
    }

    func stop(publishing status: MeetupProgressStatus? = .stopped) async {
        let endingMeetup = activeMeetup
        if let status, let meetup = activeMeetup,
           meetup.currentParticipant?.shareLevel != .off {
            await publish(
                progress: MeetupProgress(
                    status: status,
                    sectionId: progress?.sectionId,
                    serviceId: progress?.serviceId,
                    station: progress?.station,
                    expectedAt: progress?.expectedAt,
                    updatedAt: .now
                ),
                presence: nil
            )
        }
        stopLocationTracking()
        heartbeatTask?.cancel()
        expiryTask?.cancel()
        deferredPublishTask?.cancel()
        heartbeatTask = nil
        expiryTask = nil
        deferredPublishTask = nil
        if activityEnabled, let endingMeetup {
            await activityManager.end(
                meetupID: endingMeetup.id,
                finalState: activityState(for: endingMeetup, ended: true),
                dismissAt: .now.addingTimeInterval(30)
            )
        }
        activeMeetup = nil
        progress = nil
        lastPublishedSample = nil
        lastPublishedAt = nil
        lastLivePublishedAt = nil
        pendingPresenceSample = nil
        lastResolvedSampleAt = nil
        trackingStartedAt = nil
        preciseLocations = [:]
        activityEnabled = false
        usesLocationTracking = false
    }

    private func startLocationTracking() {
        guard locationTask == nil else { return }
        trackingStartedAt = .now
        let updates = locationModel.startJourneyTracking(
            allowsBackgroundUpdates: true,
            requestsAlwaysAuthorization: false
        )
        usesLocationTracking = true
        locationTask = Task { [weak self] in
            for await sample in updates {
                guard !Task.isCancelled, let self else { return }
                await self.receive(sample)
            }
        }
    }

    private func stopLocationTracking() {
        locationTask?.cancel()
        locationTask = nil
        if usesLocationTracking {
            locationModel.stopJourneyTracking()
            usesLocationTracking = false
        }
        lastPublishedSample = nil
        lastPublishedAt = nil
        lastResolvedSampleAt = nil
        trackingStartedAt = nil
    }

    /// Called only by the live screen's foreground task. Cancellation stops
    /// polling immediately when the map leaves the foreground.
    func observeWhileVisible(meetupId: String) async {
        if pollingMeetupID != meetupId {
            pollingMeetupID = meetupId
            snapshot = nil
            preciseLocations = [:]
        }
        var revision = snapshot?.revision ?? 0
        while !Task.isCancelled {
            do {
                let next = try await transport.poll(meetupId: meetupId, sinceRevision: revision)
                revision = next.revision
                if next.changed {
                    snapshot = next
                    if let meetup = next.meetup {
                        if activeMeetup?.id == meetup.id {
                            let previousPlanRevision = activeMeetup?.plan?.revision
                            activeMeetup = meetup
                            if progress?.status == .missed,
                               previousPlanRevision != meetup.plan?.revision {
                                progress = initialProgress(for: meetup)
                                lastResolvedSampleAt = nil
                            }
                        }
                        try? await transport.synchronizeGroupKey(for: meetup)
                    }
                    await decrypt(next)
                    await updateActivity()
                }
                error = nil
            } catch is CancellationError {
                return
            } catch {
                self.error = error.via
            }
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
        }
    }

    private func receive(_ sample: LocationSample) async {
        guard let meetup = activeMeetup,
              sample.recordedAt >= (lastResolvedSampleAt ?? .distantPast)
        else { return }
        lastResolvedSampleAt = sample.recordedAt

        let didChangeProgress = await resolveProgress(
            for: meetup,
            sample: sample,
            at: .now
        )
        guard activeMeetup?.id == meetup.id else { return }

        let sendsPreciseLocation = meetup.currentParticipant?.shareLevel == .positionAndProgress
            && precisePresenceEnabled()
            && MeetupLivePublishingPolicy.shouldPublish(
                sample: sample,
                after: lastPublishedSample,
                publishedAt: lastPublishedAt
            )
        guard sendsPreciseLocation || didChangeProgress else { return }
        if shouldDeferPublish(at: .now) {
            scheduleDeferredPublish(presenceSample: sendsPreciseLocation ? sample : nil)
            return
        }

        await publishCurrent(presenceSample: sendsPreciseLocation ? sample : nil)
    }

    private func publishCurrent(presenceSample sample: LocationSample?) async {
        guard let meetup = activeMeetup else { return }
        guard let sample,
              MeetupLivePublishingPolicy.isFresh(sample: sample, now: .now),
              meetup.currentParticipant?.shareLevel == .positionAndProgress,
              precisePresenceEnabled(),
              MeetupLivePublishingPolicy.shouldPublish(
                  sample: sample,
                  after: lastPublishedSample,
                  publishedAt: lastPublishedAt
              )
        else {
            await publish(progress: progress, presence: nil)
            return
        }
        do {
            let presence = try await cryptography.encrypt(
                location: MeetupPreciseLocation(sample: sample),
                meetupId: meetup.id,
                revision: meetup.keyRevision
            )
            if await publish(progress: progress, presence: presence) {
                lastPublishedSample = sample
                lastPublishedAt = sample.recordedAt
            }
        } catch {
            // A membership rotation intentionally creates this pause. The
            // plaintext progression stays available while envelopes catch up.
            await publish(progress: progress, presence: nil)
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(MeetupLivePublishingPolicy.heartbeatInterval))
                } catch { return }
                guard let self else { return }
                if let sample = self.locationModel.lastSample,
                   sample.recordedAt >= (self.trackingStartedAt ?? .distantFuture) {
                    _ = await self.resolveProgress(
                        for: self.activeMeetup,
                        sample: sample,
                        at: .now
                    )
                }
                guard let progress = self.progress else { return }
                if self.shouldDeferPublish(at: .now) {
                    self.scheduleDeferredPublish(presenceSample: nil)
                    continue
                }
                await self.publish(
                    progress: MeetupProgress(
                        status: progress.status,
                        sectionId: progress.sectionId,
                        serviceId: progress.serviceId,
                        station: progress.station,
                        expectedAt: progress.expectedAt,
                        updatedAt: .now
                    ),
                    presence: nil
                )
            }
        }
    }

    private func startExpiryTimer(for meetup: Meetup) {
        let deadline = meetup.targetArrivalAt.addingTimeInterval(2 * 60 * 60)
        expiryTask = Task { [weak self] in
            do {
                try await Task.sleep(until: .now + .seconds(max(0, deadline.timeIntervalSinceNow)))
            } catch { return }
            guard let self else { return }
            await self.stop()
        }
    }

    private func updateActivity() async {
        guard activityEnabled, let meetup = activeMeetup else { return }
        await activityManager.update(
            meetupID: meetup.id,
            state: activityState(for: meetup),
            staleAt: .now.addingTimeInterval(60)
        )
    }

    private func activityState(
        for meetup: Meetup,
        ended: Bool = false
    ) -> MeetupActivityAttributes.ContentState {
        let currentID = meetup.currentParticipantId
        let nextJoin = meetup.plan?.joinPoints.first { point in
            point.participantIds.contains(currentID) && point.meetAt >= .now
        }
        let otherNames = nextJoin?.participantIds.compactMap { participantID in
            meetup.participants.first { $0.id == participantID && $0.id != currentID }?.displayName
        }
        let expectedArrival = meetup.currentParticipant?.arrivalAt ?? meetup.targetArrivalAt
        let delta = Int((expectedArrival.timeIntervalSince(meetup.targetArrivalAt) / 60).rounded())
        let underwayCount = snapshot?.participants.filter {
            $0.progress?.status == .underway || $0.progress?.status == .joined
                || $0.progress?.status == .arrived
        }.count ?? (progress?.status == .underway ? 1 : 0)
        let state: MeetupActivityAttributes.GroupState
        if ended {
            state = .ended
        } else if progress?.status == .arrived || meetup.phase == .completed {
            state = .arrived
        } else if meetup.plan?.status == .fallbackAtDestination {
            state = .fallback
        } else if progress?.status == .joined {
            state = .joined
        } else if meetup.phase == .live {
            state = .converging
        } else {
            state = .preparing
        }
        return MeetupActivityAttributes.ContentState(
            nextDepartureAt: meetup.currentParticipant?.departureAt.flatMap { $0 > .now ? $0 : nil },
            joinPersonName: otherNames?.joined(separator: " et "),
            joinStationName: nextJoin?.station.name,
            joinZone: nextJoin.map { point in
                switch point.zone {
                case .front: .front
                case .middle: .middle
                case .rear: .rear
                }
            },
            arrivalDeltaMinutes: delta,
            expectedArrivalAt: expectedArrival,
            groupState: state,
            groupSummary: ended
                ? "Rendez-vous terminé"
                : "\(underwayCount) sur \(meetup.participants.count) en route"
        )
    }

    @discardableResult
    private func publish(
        progress: MeetupProgress?,
        presence: MeetupEncryptedPresence?
    ) async -> Bool {
        guard let meetupId = activeMeetup?.id,
              progress != nil || presence != nil else { return false }
        do {
            _ = try await transport.publish(
                meetupId: meetupId,
                progress: progress,
                presence: presence
            )
            lastLivePublishedAt = .now
            error = nil
            return true
        } catch {
            self.error = error.via
            return false
        }
    }

    private func shouldDeferPublish(at now: Date) -> Bool {
        MeetupLivePublishingPolicy.publicationDelay(
            after: lastLivePublishedAt,
            now: now
        ) > 0
    }

    private func scheduleDeferredPublish(presenceSample: LocationSample?) {
        if let presenceSample,
           presenceSample.recordedAt >= (pendingPresenceSample?.recordedAt ?? .distantPast) {
            pendingPresenceSample = presenceSample
        }
        guard deferredPublishTask == nil else { return }
        let delay = MeetupLivePublishingPolicy.publicationDelay(
            after: lastLivePublishedAt,
            now: .now
        )
        deferredPublishTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch { return }
            guard let self else { return }
            self.deferredPublishTask = nil
            if self.shouldDeferPublish(at: .now) {
                self.scheduleDeferredPublish(presenceSample: nil)
                return
            }
            let sample = self.pendingPresenceSample
            self.pendingPresenceSample = nil
            await self.publishCurrent(presenceSample: sample)
        }
    }

    @discardableResult
    private func resolveProgress(
        for meetup: Meetup?,
        sample: LocationSample,
        at now: Date
    ) async -> Bool {
        guard let meetup,
              let next = MeetupProgressResolver.resolve(
                  meetup: meetup,
                  sample: sample,
                  previous: progress,
                  now: now
              ), MeetupProgressResolver.hasMeaningfulChange(from: progress, to: next)
        else { return false }

        progress = next
        await updateActivity()
        if next.status == .arrived {
            await publish(progress: next, presence: nil)
            await stop(publishing: nil)
        }
        return true
    }

    private func initialProgress(for meetup: Meetup) -> MeetupProgress {
        let departureAt = meetup.currentParticipant?.departureAt
        let status: MeetupProgressStatus = departureAt.map {
            $0 > Date.now ? .waiting : .underway
        } ?? .underway
        return MeetupProgress(
            status: status,
            sectionId: nil,
            serviceId: nil,
            station: meetup.currentParticipant?.firstBoardingStation,
            expectedAt: status == .waiting
                ? departureAt
                : meetup.currentParticipant?.arrivalAt,
            updatedAt: .now
        )
    }

    private func decrypt(_ next: MeetupLiveSnapshot) async {
        var values: [String: MeetupPreciseLocation] = [:]
        for participant in next.participants {
            guard let presence = participant.presence,
                  let value = try? await cryptography.decrypt(
                    presence: presence,
                    meetupId: activeMeetup?.id ?? next.meetup?.id ?? ""
                  )
            else { continue }
            values[participant.participantId] = value
        }
        preciseLocations = values
    }
}
