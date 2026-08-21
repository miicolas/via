import Foundation
import Observation
import UIKit
import UserNotifications

@MainActor
@Observable
final class PushNotificationManager: JourneyActivityPushTokenSink, JourneyNotificationActiveJourneyManaging {
    static let shared = PushNotificationManager()

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var lastError: String?
    private(set) var pendingRoute: URL?

    private let installationID: String
    private var configuration: AppConfiguration?
    private var remote: any PushNotificationRemote = NoOpPushNotificationRemote()
    private var pendingDeviceToken: String?
    private var pendingActivities: [String: PushActivityRegistration] = [:]
    private var pendingActivityRemovals = Set<String>()
    private var pendingPushToStartToken: String?
    private var pendingActiveJourneyRegistration: PushActiveJourneyRegistration?
    private var pendingActiveJourneyRemoval: (installationID: String, journeyID: String)?
    private var desiredActiveJourney: Journey?
    private var isAuthenticated = false
    private var isFlushing = false

    init(defaults: UserDefaults = .standard) {
        let key = "via.push.installation-id.v1"
        if let stored = defaults.string(forKey: key), !stored.isEmpty {
            installationID = stored
        } else {
            let generated = UUID().uuidString.lowercased()
            defaults.set(generated, forKey: key)
            installationID = generated
        }
    }

    static var preview: PushNotificationManager { PushNotificationManager() }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    func configure(configuration: AppConfiguration, remote: any PushNotificationRemote) {
        self.configuration = configuration
        self.remote = remote
        Task {
            await refreshAuthorizationStatus()
            await flush()
        }
    }

    /// APNs may have delivered the current device token before an account
    /// existed. Ask iOS for it again when a signed-in account becomes active
    /// so the token can be associated with that account without persisting it.
    func registerForAuthenticatedSession() async {
        isAuthenticated = true
        UIApplication.shared.registerForRemoteNotifications()
        await flush()
    }

    func setAuthenticated(_ authenticated: Bool) async {
        isAuthenticated = authenticated
        if !authenticated {
            desiredActiveJourney = nil
            pendingActiveJourneyRegistration = nil
            pendingActiveJourneyRemoval = nil
        } else if let desiredActiveJourney {
            pendingActiveJourneyRegistration = activeJourneyRegistration(for: desiredActiveJourney)
            pendingActiveJourneyRemoval = nil
        }
        await flush()
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await refreshAuthorizationStatus()
            UIApplication.shared.registerForRemoteNotifications()
            await flush()
        } catch {
            lastError = "Les notifications n’ont pas pu être activées."
        }
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
        guard let rawRoute, let route = URL(string: rawRoute) else { return }
        pendingRoute = route
    }

    func consumePendingRoute() -> URL? {
        defer { pendingRoute = nil }
        return pendingRoute
    }

    func flush() async {
        guard !isFlushing, let configuration else { return }
        guard pendingDeviceToken != nil || !pendingActivities.isEmpty ||
            !pendingActivityRemovals.isEmpty || pendingPushToStartToken != nil ||
            pendingActiveJourneyRegistration != nil || pendingActiveJourneyRemoval != nil else { return }

        isFlushing = true
        defer { isFlushing = false }

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
                if pendingDeviceToken == deviceToken { pendingDeviceToken = nil }
            } catch {
                lastError = "Le token APNs sera réessayé plus tard."
            }
        }

        for activityID in Array(pendingActivityRemovals) {
            do {
                try await remote.unregisterActivity(activityID: activityID)
                pendingActivityRemovals.remove(activityID)
            } catch {
                lastError = "Le token de l’activité sera supprimé plus tard."
            }
        }

        for (activityID, registration) in Array(pendingActivities) {
            do {
                try await remote.registerActivity(registration)
                if pendingActivities[activityID] == registration {
                    pendingActivities.removeValue(forKey: activityID)
                }
            } catch {
                lastError = "Le token de l’activité sera réessayé plus tard."
            }
        }

        if let pushToStartToken = pendingPushToStartToken {
            do {
                try await remote.registerPushToStart(
                    PushToStartRegistration(
                        installationID: installationID,
                        pushToStartToken: pushToStartToken,
                        configuration: configuration,
                        appVersion: Bundle.main.marketingVersion,
                        osVersion: UIDevice.current.systemVersion
                    )
                )
                if pendingPushToStartToken == pushToStartToken {
                    pendingPushToStartToken = nil
                }
            } catch {
                lastError = "Le démarrage distant sera réessayé plus tard."
            }
        }

        guard isAuthenticated else { return }

        if let removal = pendingActiveJourneyRemoval {
            do {
                try await remote.unregisterActiveJourney(
                    installationID: removal.installationID,
                    journeyID: removal.journeyID
                )
                if pendingActiveJourneyRemoval?.journeyID == removal.journeyID {
                    pendingActiveJourneyRemoval = nil
                }
            } catch {
                lastError = "La désinscription du trajet sera réessayée plus tard."
            }
        }

        if let registration = pendingActiveJourneyRegistration {
            do {
                try await remote.registerActiveJourney(registration)
                if pendingActiveJourneyRegistration == registration {
                    pendingActiveJourneyRegistration = nil
                }
            } catch {
                lastError = "Les alertes de perturbation seront réessayées plus tard."
            }
        }
    }

    func unregisterCurrentInstallation() async {
        do {
            try await remote.unregisterDevice(installationID: installationID)
            pendingDeviceToken = nil
            pendingActivities.removeAll()
            pendingActivityRemovals.removeAll()
            pendingPushToStartToken = nil
            desiredActiveJourney = nil
            pendingActiveJourneyRegistration = nil
            pendingActiveJourneyRemoval = nil
        } catch {
            lastError = "La désinscription sera réessayée plus tard."
        }
    }

    func registerActiveJourney(_ journey: Journey) async {
        desiredActiveJourney = journey
        if isAuthenticated {
            pendingActiveJourneyRegistration = activeJourneyRegistration(for: journey)
            pendingActiveJourneyRemoval = nil
        }
        await flush()
    }

    func unregisterActiveJourney(_ journey: Journey) async {
        desiredActiveJourney = nil
        pendingActiveJourneyRegistration = nil
        guard isAuthenticated else { return }
        pendingActiveJourneyRemoval = (installationID, journey.id.rawValue)
        await flush()
    }

    private func activeJourneyRegistration(for journey: Journey) -> PushActiveJourneyRegistration {
        let routeIDs = Array(
            Set(journey.sections.compactMap { $0.route?.id.rawValue })
        ).sorted()
        return PushActiveJourneyRegistration(
            installationID: installationID,
            journeyID: journey.id.rawValue,
            routeIDs: routeIDs,
            startsAt: journey.departureAt,
            endsAt: journey.arrivalAt
        )
    }

    nonisolated func registerActivityPushToken(
        _ token: Data,
        activityID: String,
        journeyID: String
    ) async {
        let tokenValue = Self.hexToken(token)
        await MainActor.run {
            guard let configuration = self.configuration else { return }
            self.pendingActivities[activityID] = PushActivityRegistration(
                installationID: self.installationID,
                activityID: activityID,
                journeyID: journeyID,
                activityToken: tokenValue,
                configuration: configuration,
                appVersion: Bundle.main.marketingVersion,
                osVersion: UIDevice.current.systemVersion
            )
            self.pendingActivityRemovals.remove(activityID)
            Task { await self.flush() }
        }
    }

    nonisolated func unregisterActivityPushToken(activityID: String) async {
        await MainActor.run {
            self.pendingActivities.removeValue(forKey: activityID)
            self.pendingActivityRemovals.insert(activityID)
            Task { await self.flush() }
        }
    }

    nonisolated func registerPushToStartToken(_ token: Data) async {
        let tokenValue = Self.hexToken(token)
        await MainActor.run {
            self.pendingPushToStartToken = tokenValue
            Task { await self.flush() }
        }
    }

    nonisolated static func hexToken(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
