import Foundation
import Observation
import Security
import UIKit
import UserNotifications

@MainActor
@Observable
final class PushNotificationManager: JourneyNotificationActiveJourneyManaging {
    static let shared = PushNotificationManager()

    private(set) var lastError: String?
    private(set) var pendingRoute: URL?

    @ObservationIgnored private let providedInstallationID: String?
    @ObservationIgnored private var resolvedInstallationID: String?
    private var configuration: AppConfiguration?
    private var remote: any PushNotificationRemote = NoOpPushNotificationRemote()
    private var pendingDeviceToken: String?
    private var pendingActiveJourneyRegistration: PushActiveJourneyRegistration?
    private var pendingRemovals = PushNotificationPendingRemovals()
    private let removalStore: any PushNotificationRemovalStoring
    private var didLoadPendingRemovals = false
    private var pendingRemovalLoadTask: Task<Result<PushNotificationPendingRemovals, Error>, Never>?
    private var pendingRemovalSaveTask: Task<Error?, Never>?
    private var pendingRemovalSaveGeneration = 0
    private var desiredActiveJourney: DesiredActiveJourney?
    private var isAuthenticated = false
    private var notificationsAuthorized: Bool?
    private var isFlushing = false
    private var needsAnotherFlush = false
    private var sessionGeneration = 0
    private var flushWaiters: [CheckedContinuation<Void, Never>] = []
    private var isUpdatingAuthorization = false
    private var authorizationWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        installationID: String? = nil,
        removalStore: any PushNotificationRemovalStoring = LocalPushNotificationRemovalStore()
    ) {
        providedInstallationID = installationID
        self.removalStore = removalStore
    }

    /// Resolved on first use rather than in `init`: reading the keychain is a
    /// synchronous XPC round trip, and `shared` is touched during app launch.
    private var installationID: String {
        if let resolvedInstallationID { return resolvedInstallationID }
        let value = providedInstallationID ?? PushInstallationIDStore.loadOrCreate()
        resolvedInstallationID = value
        return value
    }

    static var preview: PushNotificationManager {
        PushNotificationManager(installationID: UUID().uuidString.lowercased())
    }

    func configure(configuration: AppConfiguration, remote: any PushNotificationRemote) {
        self.configuration = configuration
        self.remote = remote
        Task { await flush() }
    }

    /// APNs may have delivered the current device token before an account
    /// existed. Ask iOS for it again when a signed-in account becomes active
    /// so the token can be associated with that account without persisting it.
    func registerForAuthenticatedSession() async {
        await loadPendingRemovals()
        sessionGeneration += 1
        isAuthenticated = true
        if let desiredActiveJourney {
            await stageActiveJourneyRegistration(desiredActiveJourney.journey, activationID: desiredActiveJourney.activationID)
        }
        await flushPendingDeviceRemoval()
        if notificationsAuthorized == true {
            UIApplication.shared.registerForRemoteNotifications()
        }
        await flush()
    }

    func setAuthenticated(_ authenticated: Bool) async {
        if authenticated {
            await registerForAuthenticatedSession()
            return
        }
        sessionGeneration += 1
        isAuthenticated = false
        pendingActiveJourneyRegistration = nil
        await loadPendingRemovals()
    }

    func setNotificationsAuthorized(_ authorized: Bool) async {
        await beginAuthorizationUpdate()
        defer { endAuthorizationUpdate() }
        await loadPendingRemovals()
        if notificationsAuthorized == authorized {
            if authorized {
                await flush()
            } else if isAuthenticated {
                await flushPendingDeviceRemoval()
            }
            return
        }
        notificationsAuthorized = authorized
        if authorized {
            if let desiredActiveJourney, isAuthenticated {
                await stageActiveJourneyRegistration(
                    desiredActiveJourney.journey,
                    activationID: desiredActiveJourney.activationID
                )
            }
            UIApplication.shared.registerForRemoteNotifications()
            await flush()
            return
        }

        await stageDeviceRemoval()
        guard isAuthenticated else { return }
        await confirmDeviceRemoval(
            failureMessage: "La désactivation serveur sera réessayée à la prochaine session."
        )
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        pendingDeviceToken = Self.hexToken(deviceToken)
        lastError = nil
        Task { await flush() }
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        lastError = "APNs : \(error.localizedDescription)"
    }

    func didReceiveNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        let rawRoute = (userInfo["url"] as? String) ?? (userInfo["deepLink"] as? String)
        if let rawRoute, let route = URL(string: rawRoute) {
            pendingRoute = route
            return
        }
        guard let journeyID = userInfo["journeyId"] as? String,
              let mode = userInfo["mode"] as? String else { return }
        var components = URLComponents()
        components.scheme = "via"
        components.host = "journey"
        components.queryItems = [
            URLQueryItem(name: "journeyId", value: journeyID),
            URLQueryItem(name: "mode", value: mode),
        ]
        pendingRoute = components.url
    }

    func muteNotification(from response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        let category = (userInfo["category"] as? String)
            ?? response.notification.request.content.categoryIdentifier
                .split(separator: ".").last.map(String.init)
        let topicID = userInfo["topicId"] as? String

        let scope: NotificationMuteScope
        let key: String
        if let topicID, !topicID.isEmpty {
            scope = .topic
            key = topicID
        } else if let category, !category.isEmpty {
            scope = .category
            key = category
        } else {
            return
        }

        Task { [weak self] in
            guard let self, isAuthenticated else { return }
            do {
                try await remote.mute(scope: scope, key: key, until: nil)
            } catch {
                lastError = "La désactivation de cette alerte sera réessayée plus tard."
            }
        }
    }

    func consumePendingRoute() -> URL? {
        defer { pendingRoute = nil }
        return pendingRoute
    }

    func flush() async {
        await loadPendingRemovals()
        guard !isFlushing else {
            needsAnotherFlush = true
            return
        }
        guard let configuration, isAuthenticated, notificationsAuthorized == true else { return }
        guard pendingDeviceToken != nil || pendingActiveJourneyRegistration != nil ||
            !pendingRemovals.journeyIDs.isEmpty else { return }

        isFlushing = true
        let generation = sessionGeneration
        defer {
            isFlushing = false
            flushWaiters.forEach { $0.resume() }
            flushWaiters.removeAll()
            if needsAnotherFlush {
                needsAnotherFlush = false
                Task { await flush() }
            }
        }

        if let deviceToken = pendingDeviceToken {
            do {
                try await remote.registerDevice(
                    PushDeviceRegistration(
                        installationID: installationID,
                        deviceToken: deviceToken,
                        configuration: configuration,
                        appVersion: Bundle.main.marketingVersion,
                        osVersion: UIDevice.current.systemVersion
                    )
                )
                guard isAuthenticated, sessionGeneration == generation else { return }
                if pendingDeviceToken == deviceToken { pendingDeviceToken = nil }
            } catch {
                lastError = "Le token APNs sera réessayé plus tard."
            }
        }

        for journeyID in pendingRemovals.journeyIDs.sorted() {
            do {
                try await remote.unregisterActiveJourney(
                    installationID: installationID,
                    journeyID: journeyID
                )
                guard isAuthenticated, sessionGeneration == generation else { return }
                pendingRemovals.journeyIDs.remove(journeyID)
                await persistPendingRemovals()
            } catch {
                lastError = "La désinscription du trajet sera réessayée plus tard."
            }
        }

        if let registration = pendingActiveJourneyRegistration {
            do {
                try await remote.registerActiveJourney(registration)
                guard isAuthenticated, sessionGeneration == generation else { return }
                if pendingActiveJourneyRegistration == registration {
                    pendingActiveJourneyRegistration = nil
                }
            } catch {
                lastError = "Les alertes de perturbation seront réessayées plus tard."
            }
        }
    }

    func unregisterCurrentInstallation() async {
        await loadPendingRemovals()
        isAuthenticated = false
        await stageDeviceRemoval()
        await confirmDeviceRemoval(
            failureMessage: "La désinscription serveur n’a pas pu être confirmée. Les notifications sont désactivées sur cet appareil."
        )
    }

    func registerActiveJourney(_ journey: Journey, activationID: UUID) async {
        await loadPendingRemovals()
        desiredActiveJourney = DesiredActiveJourney(journey: journey, activationID: activationID)
        if isAuthenticated {
            await stageActiveJourneyRegistration(journey, activationID: activationID)
        }
        await flush()
    }

    func unregisterActiveJourney(_ journey: Journey, activationID: UUID) async {
        await loadPendingRemovals()
        let desired = desiredActiveJourney
        let pending = pendingActiveJourneyRegistration

        // A late cleanup from activation A must not undo a newer activation B.
        // The server only addresses journeys by ID, so enqueueing A here would
        // be ambiguous when both activations intentionally share that ID.
        if let desired, desired.activationID != activationID,
           desired.journey.id == journey.id {
            if pending?.activationID == activationID {
                pendingActiveJourneyRegistration = nil
            }
            return
        }

        if desired?.activationID == activationID {
            desiredActiveJourney = nil
        }
        if pending?.activationID == activationID {
            pendingActiveJourneyRegistration = nil
        }
        guard isAuthenticated else { return }
        pendingRemovals.journeyIDs.insert(journey.id.rawValue)
        await persistPendingRemovals()
        await flush()
    }

    private func loadPendingRemovals() async {
        guard !didLoadPendingRemovals else { return }
        let task: Task<Result<PushNotificationPendingRemovals, Error>, Never>
        if let pendingRemovalLoadTask {
            task = pendingRemovalLoadTask
        } else {
            task = Task {
                do {
                    return .success(try await removalStore.load())
                } catch {
                    return .failure(error)
                }
            }
            pendingRemovalLoadTask = task
        }
        let result = await task.value
        guard !didLoadPendingRemovals else { return }
        switch result {
        case .success(let stored):
            pendingRemovals = stored
            didLoadPendingRemovals = true
        case .failure:
            // A corrupt outbox must fail closed: removing the installation is
            // safer than silently retaining subscriptions we can no longer decode.
            pendingRemovals = PushNotificationPendingRemovals(unregisterDevice: true)
            didLoadPendingRemovals = true
            do {
                try await removalStore.save(pendingRemovals)
                lastError = "Les notifications serveur seront réinitialisées par sécurité."
            } catch {
                didLoadPendingRemovals = false
                lastError = "Les désinscriptions en attente n’ont pas pu être relues."
            }
        }
        pendingRemovalLoadTask = nil
    }

    private func persistPendingRemovals() async {
        let snapshot = pendingRemovals
        let previous = pendingRemovalSaveTask
        pendingRemovalSaveGeneration += 1
        let generation = pendingRemovalSaveGeneration
        let task = Task { () -> Error? in
            _ = await previous?.value
            do {
                try await removalStore.save(snapshot)
                return nil
            } catch {
                return error
            }
        }
        pendingRemovalSaveTask = task
        if await task.value != nil {
            lastError = "Les désinscriptions en attente n’ont pas pu être enregistrées."
        }
        if pendingRemovalSaveGeneration == generation {
            pendingRemovalSaveTask = nil
        }
    }

    private func flushPendingDeviceRemoval() async {
        guard pendingRemovals.unregisterDevice else { return }
        await confirmDeviceRemoval(
            failureMessage: "La désinscription serveur sera réessayée à la prochaine session."
        )
    }

    /// Staging a registration must also cancel any queued removal for the same
    /// journey, or the next flush would immediately undo it.
    private func stageActiveJourneyRegistration(_ journey: Journey, activationID: UUID) async {
        pendingActiveJourneyRegistration = activeJourneyRegistration(for: journey, activationID: activationID)
        pendingRemovals.journeyIDs.remove(journey.id.rawValue)
        await persistPendingRemovals()
    }

    /// Stops local push activity and records the pending server removal so a
    /// failed or skipped remote call is retried on the next session.
    private func stageDeviceRemoval() async {
        sessionGeneration += 1
        UIApplication.shared.unregisterForRemoteNotifications()
        pendingDeviceToken = nil
        pendingActiveJourneyRegistration = nil
        pendingRemovals.unregisterDevice = true
        await persistPendingRemovals()
        await waitForFlushToFinish()
    }

    /// Clears the staged removal only once the server confirms it.
    private func confirmDeviceRemoval(failureMessage: String) async {
        do {
            try await remote.unregisterDevice(installationID: installationID)
            pendingRemovals.unregisterDevice = false
            pendingRemovals.journeyIDs.removeAll()
            await persistPendingRemovals()
        } catch {
            lastError = failureMessage
        }
    }

    private func activeJourneyRegistration(for journey: Journey, activationID: UUID) -> PushActiveJourneyRegistration? {
        let transitSchedules = ActiveJourneyRules.schedule(for: journey)
            .filter { $0.section.kind == .transit && $0.section.route != nil }
        let routeWindows = transitSchedules.enumerated().compactMap { index, schedule -> PushRouteWindow? in
            guard let routeID = schedule.section.route?.id.rawValue else {
                return nil
            }
            let isLastTransitSection = index == transitSchedules.indices.last
            return PushRouteWindow(
                routeID: routeID,
                startsAt: schedule.startsAt,
                endsAt: isLastTransitSection
                    ? schedule.endsAt.addingTimeInterval(ActiveJourneyRules.restorationGracePeriod)
                    : schedule.endsAt
            )
        }
        guard !routeWindows.isEmpty else { return nil }
        return PushActiveJourneyRegistration(
            installationID: installationID,
            journeyID: journey.id.rawValue,
            activationID: activationID,
            routeWindows: routeWindows,
            startsAt: journey.departureAt.addingTimeInterval(
                -ActiveJourneyRules.imminentDepartureInterval
            ),
            endsAt: journey.arrivalAt.addingTimeInterval(
                ActiveJourneyRules.restorationGracePeriod
            )
        )
    }

    private func waitForFlushToFinish() async {
        guard isFlushing else { return }
        await withCheckedContinuation { continuation in
            flushWaiters.append(continuation)
        }
    }

    private func beginAuthorizationUpdate() async {
        if isUpdatingAuthorization {
            await withCheckedContinuation { continuation in
                authorizationWaiters.append(continuation)
            }
            return
        }
        isUpdatingAuthorization = true
    }

    private func endAuthorizationUpdate() {
        if authorizationWaiters.isEmpty {
            isUpdatingAuthorization = false
        } else {
            authorizationWaiters.removeFirst().resume()
        }
    }

    nonisolated static func hexToken(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

private struct DesiredActiveJourney: Sendable, Hashable {
    let journey: Journey
    let activationID: UUID
}

private enum PushInstallationIDStore {
    private static let service = "dev.via.app.push-installation-id.v2"
    private static let legacyDefaultsKey = "via.push.installation-id.v1"

    static func loadOrCreate(defaults: UserDefaults = .standard) -> String {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        var readQuery = baseQuery
        readQuery[kSecReturnData as String] = true
        readQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        if SecItemCopyMatching(readQuery as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8),
           !value.isEmpty {
            defaults.removeObject(forKey: legacyDefaultsKey)
            return value
        }

        let legacyValue = defaults.string(forKey: legacyDefaultsKey)
            .flatMap { $0.isEmpty ? nil : $0 }
        let value = legacyValue ?? UUID().uuidString.lowercased()
        var values = baseQuery
        values[kSecValueData as String] = Data(value.utf8)
        values[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemDelete(baseQuery as CFDictionary)
        guard SecItemAdd(values as CFDictionary, nil) == errSecSuccess else {
            return value
        }
        defaults.removeObject(forKey: legacyDefaultsKey)
        return value
    }
}
