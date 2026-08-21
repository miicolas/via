import Foundation

struct PushDeviceRegistration: Sendable, Hashable {
    let installationID: String
    let deviceToken: String
    let configuration: AppConfiguration
    let appVersion: String?
    let osVersion: String?
}

struct PushActivityRegistration: Sendable, Hashable {
    let installationID: String
    let activityID: String
    let journeyID: String
    let activityToken: String
    let configuration: AppConfiguration
    let appVersion: String?
    let osVersion: String?
}

struct PushToStartRegistration: Sendable, Hashable {
    let installationID: String
    let pushToStartToken: String
    let configuration: AppConfiguration
    let appVersion: String?
    let osVersion: String?
}

struct PushActiveJourneyRegistration: Sendable, Hashable {
    let installationID: String
    let journeyID: String
    let routeIDs: [String]
    let startsAt: Date
    let endsAt: Date
}

protocol PushNotificationRemote: Sendable {
    func registerDevice(_ registration: PushDeviceRegistration) async throws
    func unregisterDevice(installationID: String) async throws
    func registerActivity(_ registration: PushActivityRegistration) async throws
    func unregisterActivity(activityID: String) async throws
    func registerPushToStart(_ registration: PushToStartRegistration) async throws
    func registerActiveJourney(_ registration: PushActiveJourneyRegistration) async throws
    func unregisterActiveJourney(installationID: String, journeyID: String) async throws
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

    func registerActivity(_ registration: PushActivityRegistration) async throws {
        try await transport.perform("notifications_register_activity") { client in
            typealias Payload = Operations.notifications_period_registerActivity.Input.Body.jsonPayload
            let payload = Payload(
                installationId: registration.installationID,
                activityId: registration.activityID,
                journeyId: registration.journeyID,
                activityToken: registration.activityToken,
                bundleId: registration.configuration.bundleIdentifier,
                environment: activityEnvironment(for: registration.configuration.apnsEnvironment),
                appVersion: registration.appVersion,
                osVersion: registration.osVersion
            )
            switch try await client.notifications_period_registerActivity(.init(body: .json(payload))) {
            case .ok:
                return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func unregisterActivity(activityID: String) async throws {
        try await transport.perform("notifications_unregister_activity") { client in
            let payload = Operations.notifications_period_unregisterActivity.Input.Body.jsonPayload(
                activityId: activityID
            )
            switch try await client.notifications_period_unregisterActivity(.init(body: .json(payload))) {
            case .ok:
                return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func registerPushToStart(_ registration: PushToStartRegistration) async throws {
        try await transport.perform("notifications_register_push_to_start") { client in
            typealias Payload = Operations.notifications_period_registerPushToStart.Input.Body.jsonPayload
            let payload = Payload(
                installationId: registration.installationID,
                pushToStartToken: registration.pushToStartToken,
                bundleId: registration.configuration.bundleIdentifier,
                environment: pushToStartEnvironment(for: registration.configuration.apnsEnvironment),
                appVersion: registration.appVersion,
                osVersion: registration.osVersion
            )
            switch try await client.notifications_period_registerPushToStart(.init(body: .json(payload))) {
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
                routeIds: registration.routeIDs,
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

    private func deviceEnvironment(
        for value: APNsEnvironment
    ) -> Operations.notifications_period_registerDevice.Input.Body.jsonPayload.environmentPayload {
        switch value {
        case .sandbox: .sandbox
        case .production: .production
        }
    }

    private func activityEnvironment(
        for value: APNsEnvironment
    ) -> Operations.notifications_period_registerActivity.Input.Body.jsonPayload.environmentPayload {
        switch value {
        case .sandbox: .sandbox
        case .production: .production
        }
    }

    private func pushToStartEnvironment(
        for value: APNsEnvironment
    ) -> Operations.notifications_period_registerPushToStart.Input.Body.jsonPayload.environmentPayload {
        switch value {
        case .sandbox: .sandbox
        case .production: .production
        }
    }
}

struct NoOpPushNotificationRemote: PushNotificationRemote {
    func registerDevice(_ registration: PushDeviceRegistration) async throws {}
    func unregisterDevice(installationID: String) async throws {}
    func registerActivity(_ registration: PushActivityRegistration) async throws {}
    func unregisterActivity(activityID: String) async throws {}
    func registerPushToStart(_ registration: PushToStartRegistration) async throws {}
    func registerActiveJourney(_ registration: PushActiveJourneyRegistration) async throws {}
    func unregisterActiveJourney(installationID: String, journeyID: String) async throws {}
}
