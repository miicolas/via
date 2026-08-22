import Foundation

struct PushDeviceRegistration: Sendable, Hashable {
    let installationID: String
    let deviceToken: String
    let configuration: AppConfiguration
    let appVersion: String?
    let osVersion: String?
}

struct PushRouteWindow: Sendable, Hashable {
    let routeID: String
    let startsAt: Date
    let endsAt: Date
}

struct PushActiveJourneyRegistration: Sendable, Hashable {
    let installationID: String
    let journeyID: String
    let routeWindows: [PushRouteWindow]
    let startsAt: Date
    let endsAt: Date
}

protocol PushNotificationRemote: Sendable {
    func registerDevice(_ registration: PushDeviceRegistration) async throws
    func unregisterDevice(installationID: String) async throws
    func registerActiveJourney(_ registration: PushActiveJourneyRegistration) async throws
    func unregisterActiveJourney(installationID: String, journeyID: String) async throws
    func mute(scope: NotificationMuteScope, key: String, until: Date?) async throws
}

enum NotificationMuteScope: String, Sendable, Hashable {
    case category
    case topic
}

struct LivePushNotificationRemote: PushNotificationRemote {
    let transport: APITransport

    func registerDevice(_ registration: PushDeviceRegistration) async throws {
        try await transport.perform("notifications_register_device") { client in
            typealias Payload = Operations.notifications_period_registerDevice.Input.Body.jsonPayload
            let payload = Payload(
                installationId: registration.installationID,
                deviceToken: registration.deviceToken,
                bundleId: registration.configuration.bundleIdentifier,
                environment: deviceEnvironment(for: registration.configuration.apnsEnvironment),
                appVersion: registration.appVersion,
                osVersion: registration.osVersion
            )
            switch try await client.notifications_period_registerDevice(.init(body: .json(payload))) {
            case .ok:
                return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func unregisterDevice(installationID: String) async throws {
        try await transport.perform("notifications_unregister_device") { client in
            let payload = Operations.notifications_period_unregisterDevice.Input.Body.jsonPayload(
                installationId: installationID
            )
            switch try await client.notifications_period_unregisterDevice(.init(body: .json(payload))) {
            case .ok:
                return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func registerActiveJourney(_ registration: PushActiveJourneyRegistration) async throws {
        try await transport.perform("notifications_register_active_journey") { client in
            let payload = Operations.notifications_period_registerActiveJourney.Input.Body.jsonPayload(
                installationId: registration.installationID,
                journeyId: registration.journeyID,
                routeWindows: registration.routeWindows.map { window in
                    .init(
                        routeId: window.routeID,
                        startsAt: window.startsAt,
                        endsAt: window.endsAt
                    )
                },
                routeIds: Array(Set(registration.routeWindows.map(\.routeID))).sorted(),
                startsAt: registration.startsAt,
                endsAt: registration.endsAt
            )
            switch try await client.notifications_period_registerActiveJourney(.init(body: .json(payload))) {
            case .ok:
                return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func unregisterActiveJourney(installationID: String, journeyID: String) async throws {
        try await transport.perform("notifications_unregister_active_journey") { client in
            let payload = Operations.notifications_period_unregisterActiveJourney.Input.Body.jsonPayload(
                installationId: installationID,
                journeyId: journeyID
            )
            switch try await client.notifications_period_unregisterActiveJourney(.init(body: .json(payload))) {
            case .ok:
                return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func mute(scope: NotificationMuteScope, key: String, until: Date?) async throws {
        try await transport.perform("notifications_mute") { client in
            let payload = Operations.notifications_period_mute.Input.Body.jsonPayload(
                scope: scope == .category ? .category : .topic,
                key: key,
                mutedUntil: until
            )
            switch try await client.notifications_period_mute(.init(body: .json(payload))) {
            case .ok:
                return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    private func deviceEnvironment(
        for value: APNsEnvironment
    ) -> Operations.notifications_period_registerDevice.Input.Body.jsonPayload.environmentPayload {
        switch value {
        case .sandbox: .sandbox
        case .production: .production
        }
    }

}

struct NoOpPushNotificationRemote: PushNotificationRemote {
    func registerDevice(_ registration: PushDeviceRegistration) async throws {}
    func unregisterDevice(installationID: String) async throws {}
    func registerActiveJourney(_ registration: PushActiveJourneyRegistration) async throws {}
    func unregisterActiveJourney(installationID: String, journeyID: String) async throws {}
    func mute(scope: NotificationMuteScope, key: String, until: Date?) async throws {}
}

extension PushNotificationRemote {
    func mute(scope: NotificationMuteScope, key: String, until: Date?) async throws {}
}
