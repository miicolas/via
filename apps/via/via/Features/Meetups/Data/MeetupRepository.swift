import Foundation

/// One edit to an existing rendez-vous. Every case is meetup-scoped and the
/// server answers each with the refreshed `Meetup`, which is why they share
/// a single `mutate` entry instead of one method per endpoint.
enum MeetupChange: Sendable, Hashable {
    case update(destination: MeetupStation?, targetArrivalAt: Date?)
    case configure(origin: MeetupOrigin?, shareLevel: MeetupShareLevel?, zone: MeetupZone?)
    case cancel
    case revokeInvitation(id: String)
    case removeParticipant(id: String)
}

/// The rendez-vous surface the screens consume. The Partage-live wire calls
/// (publish, poll, activity registration, key sync) live on
/// `MeetupLiveTransport`; `create`, the invitation flow and `leave` keep
/// their own methods because they are not meetup-scoped or do not answer
/// with a `Meetup`.
protocol MeetupRepository: Sendable {
    func list() async throws -> MeetupListing
    func load(meetupId: String) async throws -> Meetup
    func create(
        destination: MeetupStation,
        targetArrivalAt: Date,
        organizerDisplayName: String,
        origin: MeetupOrigin,
        shareLevel: MeetupShareLevel
    ) async throws -> Meetup
    func mutate(meetupId: String, change: MeetupChange) async throws -> Meetup
    func invitation(meetupId: String, invitedUserId: String?) async throws -> MeetupInvitationLink
    func previewInvitation(token: String) async throws -> MeetupInvitationPreview
    func acceptInvitation(
        token: String,
        groupKey: String?,
        displayName: String,
        origin: MeetupOrigin,
        shareLevel: MeetupShareLevel
    ) async throws -> Meetup
    func declineInvitation(token: String) async throws
    func leave(meetupId: String) async throws
}

struct LiveMeetupRepository: MeetupRepository, MeetupLiveTransport {
    let transport: APITransport
    let credentials: any MeetupCredentialStoring
    let cryptography: any MeetupCryptography

    func list() async throws -> MeetupListing {
        let accountListing: MeetupListResponseDTO = try await transport.perform("meetups.list") { client in
            switch try await client.meetups_period_list(.init()) {
            case .ok(let response):
                return try transport.convert(
                    response.body.json,
                    to: MeetupListResponseDTO.self
                )
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
        let accountMeetups = accountListing.meetups
        let existing = Set(accountMeetups.map(\.id))
        let anonymous = try await credentials.allCredentials()
        let localMeetups = await withTaskGroup(of: Meetup?.self) { group in
            for credential in anonymous where !existing.contains(credential.meetupId) {
                group.addTask { try? await load(meetupId: credential.meetupId) }
            }
            var values: [Meetup] = []
            for await value in group {
                if let value { values.append(value) }
            }
            return values
        }
        return MeetupListing(
            meetups: (accountMeetups + localMeetups).sorted {
                $0.targetArrivalAt < $1.targetArrivalAt
            },
            pendingInvitations: accountListing.pendingInvitations
        )
    }

    func load(meetupId: String) async throws -> Meetup {
        let token = try await credentials.credential(for: meetupId)?.participantToken
        return try await transport.perform("meetups.get") { client in
            let input = Operations.meetups_period_get.Input(
                query: .init(meetupId: meetupId),
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: token)
            )
            switch try await client.meetups_period_get(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: Meetup.self)
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func create(
        destination: MeetupStation,
        targetArrivalAt: Date,
        organizerDisplayName: String,
        origin: MeetupOrigin,
        shareLevel: MeetupShareLevel
    ) async throws -> Meetup {
        let identity = try await cryptography.deviceIdentity()
        let dto = MeetupCreateRequestDTO(
            destination: destination,
            targetArrivalAt: targetArrivalAt,
            organizerDisplayName: organizerDisplayName,
            origin: origin,
            shareLevel: shareLevel,
            publicKey: identity.publicKey,
            idempotencyKey: UUID().uuidString.lowercased()
        )
        let result: MeetupCreateResponseDTO = try await transport.perform("meetups.create") { client in
            typealias Payload = Operations.meetups_period_create.Input.Body.jsonPayload
            let payload = try transport.convert(dto, to: Payload.self)
            switch try await client.meetups_period_create(.init(body: .json(payload))) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: MeetupCreateResponseDTO.self)
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
        let deviceKeyId = UUID().uuidString.lowercased()
        try await credentials.store(.init(
            meetupId: result.meetup.id,
            participantToken: result.participantToken,
            deviceKeyId: deviceKeyId
        ))
        _ = try await cryptography.createGroupKey(
            meetupId: result.meetup.id,
            revision: result.meetup.keyRevision
        )
        try await registerDeviceIdentity(
            identity,
            meetupId: result.meetup.id,
            keyId: deviceKeyId
        )
        return result.meetup
    }

    func mutate(meetupId: String, change: MeetupChange) async throws -> Meetup {
        switch change {
        case .update(let destination, let targetArrivalAt):
            try await update(
                meetupId: meetupId,
                destination: destination,
                targetArrivalAt: targetArrivalAt
            )
        case .configure(let origin, let shareLevel, let zone):
            try await configure(
                meetupId: meetupId,
                origin: origin,
                shareLevel: shareLevel,
                zone: zone
            )
        case .cancel:
            try await cancel(meetupId: meetupId)
        case .revokeInvitation(let id):
            try await revokeInvitation(meetupId: meetupId, invitationId: id)
        case .removeParticipant(let id):
            try await remove(meetupId: meetupId, participantId: id)
        }
    }

    private func update(
        meetupId: String,
        destination: MeetupStation?,
        targetArrivalAt: Date?
    ) async throws -> Meetup {
        try await mutation(
            operation: "meetups.update",
            meetupId: meetupId,
            dto: MeetupUpdateRequestDTO(
                meetupId: meetupId,
                destination: destination,
                targetArrivalAt: targetArrivalAt
            ),
            payload: Operations.meetups_period_update.Input.Body.jsonPayload.self,
            perform: { client, headers, payload in
                try await client.meetups_period_update(.init(headers: headers, body: .json(payload)))
            }
        )
    }

    private func cancel(meetupId: String) async throws -> Meetup {
        let token = try await credentials.credential(for: meetupId)?.participantToken
        return try await transport.perform("meetups.cancel") { client in
            let payload = Operations.meetups_period_cancel.Input.Body.jsonPayload(meetupId: meetupId)
            let input = Operations.meetups_period_cancel.Input(
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: token),
                body: .json(payload)
            )
            switch try await client.meetups_period_cancel(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: MeetupMutationDTO.self).meetup
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func invitation(meetupId: String, invitedUserId: String?) async throws -> MeetupInvitationLink {
        let meetup = try await load(meetupId: meetupId)
        let token = try await credentials.credential(for: meetupId)?.participantToken
        let dto = MeetupInvitationCreateRequestDTO(
            meetupId: meetupId,
            invitedUserId: invitedUserId,
            keyEnvelopes: [],
            idempotencyKey: UUID().uuidString.lowercased()
        )
        let result: MeetupInvitationCreateResponseDTO = try await transport.perform(
            "meetups.createInvitation"
        ) { client in
            typealias Payload = Operations.meetups_period_createInvitation.Input.Body.jsonPayload
            let payload = try transport.convert(dto, to: Payload.self)
            let input = Operations.meetups_period_createInvitation.Input(
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: token),
                body: .json(payload)
            )
            switch try await client.meetups_period_createInvitation(input) {
            case .ok(let response):
                return try transport.convert(
                    response.body.json,
                    to: MeetupInvitationCreateResponseDTO.self
                )
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
        guard var components = URLComponents(string: result.url) else { throw ViaError.decoding }
        // Direct friend invitations may also be forwarded as links. The group
        // key remains in the fragment and therefore never reaches the server.
        let key = try await cryptography.groupKeyFragment(
            meetupId: meetupId,
            revision: meetup.keyRevision
        )
        components.fragment = "k=\(key)"
        guard let url = components.url else { throw ViaError.decoding }
        return MeetupInvitationLink(
            id: result.invitation.id,
            url: url,
            expiresAt: result.invitation.expiresAt
        )
    }

    func previewInvitation(token: String) async throws -> MeetupInvitationPreview {
        try await transport.perform("meetups.previewInvitation") { client in
            switch try await client.meetups_period_previewInvitation(
                .init(query: .init(token: token))
            ) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: MeetupInvitationPreview.self)
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func acceptInvitation(
        token: String,
        groupKey: String?,
        displayName: String,
        origin: MeetupOrigin,
        shareLevel: MeetupShareLevel
    ) async throws -> Meetup {
        let identity = try await cryptography.deviceIdentity()
        let deviceKeyId = UUID().uuidString.lowercased()
        let dto = MeetupInvitationAcceptRequestDTO(
            token: token,
            displayName: displayName,
            origin: origin,
            shareLevel: shareLevel,
            publicKey: identity.publicKey,
            keyId: deviceKeyId,
            idempotencyKey: UUID().uuidString.lowercased()
        )
        let result: MeetupAcceptResponseDTO = try await transport.perform(
            "meetups.acceptInvitation"
        ) { client in
            typealias Payload = Operations.meetups_period_acceptInvitation.Input.Body.jsonPayload
            let payload = try transport.convert(dto, to: Payload.self)
            switch try await client.meetups_period_acceptInvitation(.init(body: .json(payload))) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: MeetupAcceptResponseDTO.self)
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
        try await credentials.store(.init(
            meetupId: result.meetup.id,
            participantToken: result.participantToken,
            deviceKeyId: deviceKeyId
        ))
        if let groupKey {
            try await cryptography.importGroupKey(
                groupKey,
                meetupId: result.meetup.id,
                revision: max(1, result.meetup.keyRevision - 1)
            )
        }
        try await synchronizeGroupKey(for: result.meetup)
        return result.meetup
    }

    func declineInvitation(token: String) async throws {
        try await transport.perform("meetups.declineInvitation") { client in
            let payload = Operations.meetups_period_declineInvitation.Input.Body.jsonPayload(
                token: token
            )
            switch try await client.meetups_period_declineInvitation(.init(body: .json(payload))) {
            case .ok: return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    private func revokeInvitation(meetupId: String, invitationId: String) async throws -> Meetup {
        let token = try await credentials.credential(for: meetupId)?.participantToken
        return try await transport.perform("meetups.revokeInvitation") { client in
            let payload = Operations.meetups_period_revokeInvitation.Input.Body.jsonPayload(
                meetupId: meetupId,
                invitationId: invitationId
            )
            let input = Operations.meetups_period_revokeInvitation.Input(
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: token),
                body: .json(payload)
            )
            switch try await client.meetups_period_revokeInvitation(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: MeetupMutationDTO.self).meetup
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    private func configure(
        meetupId: String,
        origin: MeetupOrigin?,
        shareLevel: MeetupShareLevel?,
        zone: MeetupZone?
    ) async throws -> Meetup {
        let token = try await credentials.credential(for: meetupId)?.participantToken
        let dto = MeetupConfigureRequestDTO(
            meetupId: meetupId,
            origin: origin,
            shareLevel: shareLevel,
            zone: zone
        )
        return try await transport.perform("meetups.configureParticipant") { client in
            typealias Payload = Operations.meetups_period_configureParticipant.Input.Body.jsonPayload
            let payload = try transport.convert(dto, to: Payload.self)
            let input = Operations.meetups_period_configureParticipant.Input(
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: token),
                body: .json(payload)
            )
            switch try await client.meetups_period_configureParticipant(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: MeetupMutationDTO.self).meetup
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func leave(meetupId: String) async throws {
        let token = try await credentials.credential(for: meetupId)?.participantToken
        try await transport.perform("meetups.leave") { client in
            let payload = Operations.meetups_period_leave.Input.Body.jsonPayload(meetupId: meetupId)
            let input = Operations.meetups_period_leave.Input(
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: token),
                body: .json(payload)
            )
            switch try await client.meetups_period_leave(input) {
            case .ok: return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
        try await credentials.remove(meetupId: meetupId)
        await cryptography.discardGroupKeys(meetupId: meetupId)
    }

    private func remove(meetupId: String, participantId: String) async throws -> Meetup {
        let token = try await credentials.credential(for: meetupId)?.participantToken
        return try await transport.perform("meetups.removeParticipant") { client in
            let payload = Operations.meetups_period_removeParticipant.Input.Body.jsonPayload(
                meetupId: meetupId,
                participantId: participantId
            )
            let input = Operations.meetups_period_removeParticipant.Input(
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: token),
                body: .json(payload)
            )
            switch try await client.meetups_period_removeParticipant(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: MeetupMutationDTO.self).meetup
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func publish(
        meetupId: String,
        progress: MeetupProgress?,
        presence: MeetupEncryptedPresence?
    ) async throws -> Int {
        let token = try await credentials.credential(for: meetupId)?.participantToken
        let dto = MeetupPublishRequestDTO(
            meetupId: meetupId,
            progress: progress,
            presence: presence
        )
        return try await transport.perform("meetups.publishLive") { client in
            typealias Payload = Operations.meetups_period_publishLive.Input.Body.jsonPayload
            let payload = try transport.convert(dto, to: Payload.self)
            let input = Operations.meetups_period_publishLive.Input(
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: token),
                body: .json(payload)
            )
            switch try await client.meetups_period_publishLive(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: MeetupPublishResponseDTO.self).revision
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func poll(meetupId: String, sinceRevision: Int) async throws -> MeetupLiveSnapshot {
        let token = try await credentials.credential(for: meetupId)?.participantToken
        return try await transport.perform("meetups.pollLive") { client in
            let input = Operations.meetups_period_pollLive.Input(
                query: .init(meetupId: meetupId, sinceRevision: sinceRevision),
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: token)
            )
            switch try await client.meetups_period_pollLive(input) {
            case .ok(let response):
                let dto = try transport.convert(response.body.json, to: MeetupPollResponseDTO.self)
                return MeetupLiveSnapshot(
                    revision: dto.revision,
                    changed: dto.changed,
                    meetup: dto.meetup,
                    participants: dto.live
                )
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func registerActivity(
        meetupId: String,
        installationId: String,
        activityId: String,
        token: String,
        environment: APNsEnvironment
    ) async throws {
        let participantToken = try await credentials.credential(for: meetupId)?.participantToken
        try await transport.perform("meetups.registerActivity") { client in
            typealias Payload = Operations.meetups_period_registerActivity.Input.Body.jsonPayload
            let payload = Payload(
                meetupId: meetupId,
                installationId: installationId,
                activityId: activityId,
                token: token,
                environment: environment == .production ? .production : .sandbox
            )
            let input = Operations.meetups_period_registerActivity.Input(
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: participantToken),
                body: .json(payload)
            )
            switch try await client.meetups_period_registerActivity(input) {
            case .ok: return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func unregisterActivity(
        meetupId: String,
        installationId: String,
        activityId: String
    ) async throws {
        let participantToken = try await credentials.credential(for: meetupId)?.participantToken
        try await transport.perform("meetups.unregisterActivity") { client in
            let payload = Operations.meetups_period_unregisterActivity.Input.Body.jsonPayload(
                meetupId: meetupId,
                installationId: installationId,
                activityId: activityId
            )
            let input = Operations.meetups_period_unregisterActivity.Input(
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: participantToken),
                body: .json(payload)
            )
            switch try await client.meetups_period_unregisterActivity(input) {
            case .ok: return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func synchronizeGroupKey(for meetup: Meetup) async throws {
        let identity = try await cryptography.deviceIdentity()
        let credential = try await credentialWithDeviceKey(meetupId: meetup.id)
        guard let keyId = credential.deviceKeyId else { throw ViaError.decoding }
        try await registerDeviceIdentity(identity, meetupId: meetup.id, keyId: keyId)

        let token = credential.participantToken
        let sync: MeetupKeySync = try await transport.perform("meetups.syncKeys") { client in
            let input = Operations.meetups_period_syncKeys.Input(
                query: .init(meetupId: meetup.id),
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: token)
            )
            switch try await client.meetups_period_syncKeys(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: MeetupKeySync.self)
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }

        if !(await cryptography.hasGroupKey(
            meetupId: meetup.id,
            revision: sync.keyRevision
        )) {
            for envelope in sync.envelopes where envelope.recipientKeyId == keyId {
                try? await cryptography.openEnvelope(
                    MeetupKeyEnvelope(
                        recipientKeyId: envelope.recipientKeyId,
                        ciphertext: envelope.ciphertext
                    ),
                    meetupId: meetup.id,
                    revision: envelope.keyRevision
                )
            }
        }

        let hasCurrentKey = await cryptography.hasGroupKey(
            meetupId: meetup.id,
            revision: sync.keyRevision
        )
        guard let decision = MeetupKeyDistributionPolicy.decision(
            hasCurrentKey: hasCurrentKey,
            sync: sync
        ) else { return }
        if decision.createsGroupKey {
            _ = try await cryptography.createGroupKey(
                meetupId: meetup.id,
                revision: sync.keyRevision
            )
        }
        let envelopes = try await decision.recipients.asyncMap { deviceKey in
            try await cryptography.envelope(
                meetupId: meetup.id,
                revision: sync.keyRevision,
                recipientKeyId: deviceKey.keyId,
                recipientPublicKey: deviceKey.publicKey
            )
        }
        guard !envelopes.isEmpty else { return }
        try await uploadKeyEnvelopes(
            meetupId: meetup.id,
            keyRevision: sync.keyRevision,
            envelopes: envelopes,
            participantToken: token
        )
    }

    private func registerDeviceIdentity(
        _ identity: MeetupDeviceIdentity,
        meetupId: String,
        keyId: String
    ) async throws {
        let token = try await credentials.credential(for: meetupId)?.participantToken
        try await transport.perform("meetups.registerDeviceKey") { client in
            let payload = Operations.meetups_period_registerDeviceKey.Input.Body.jsonPayload(
                meetupId: meetupId,
                keyId: keyId,
                publicKey: identity.publicKey
            )
            let input = Operations.meetups_period_registerDeviceKey.Input(
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: token),
                body: .json(payload)
            )
            switch try await client.meetups_period_registerDeviceKey(input) {
            case .ok: return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    private func credentialWithDeviceKey(
        meetupId: String
    ) async throws -> MeetupParticipantCredential {
        let credential = try await credentials.credential(for: meetupId)
            ?? MeetupParticipantCredential(
                meetupId: meetupId,
                participantToken: nil,
                deviceKeyId: nil
            )
        if credential.deviceKeyId != nil { return credential }
        let migrated = MeetupParticipantCredential(
            meetupId: meetupId,
            participantToken: credential.participantToken,
            deviceKeyId: UUID().uuidString.lowercased()
        )
        try await credentials.store(migrated)
        return migrated
    }

    private func uploadKeyEnvelopes(
        meetupId: String,
        keyRevision: Int,
        envelopes: [MeetupKeyEnvelope],
        participantToken: String?
    ) async throws {
        let dto = MeetupEnvelopeUploadDTO(
            meetupId: meetupId,
            keyRevision: keyRevision,
            envelopes: envelopes
        )
        try await transport.perform("meetups.uploadKeyEnvelopes") { client in
            typealias Payload = Operations.meetups_period_uploadKeyEnvelopes.Input.Body.jsonPayload
            let payload = try transport.convert(dto, to: Payload.self)
            let input = Operations.meetups_period_uploadKeyEnvelopes.Input(
                headers: .init(x_hyphen_via_hyphen_meetup_hyphen_token: participantToken),
                body: .json(payload)
            )
            switch try await client.meetups_period_uploadKeyEnvelopes(input) {
            case .ok: return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    private func mutation<DTO: Encodable, Payload: Codable & Sendable & Hashable>(
        operation: StaticString,
        meetupId: String,
        dto: DTO,
        payload: Payload.Type,
        perform: (Client, Operations.meetups_period_update.Input.Headers, Payload) async throws
            -> Operations.meetups_period_update.Output
    ) async throws -> Meetup {
        let token = try await credentials.credential(for: meetupId)?.participantToken
        return try await transport.perform(operation) { client in
            let converted = try transport.convert(dto, to: payload)
            let response = try await perform(
                client,
                .init(x_hyphen_via_hyphen_meetup_hyphen_token: token),
                converted
            )
            switch response {
            case .ok(let response):
                return try transport.convert(response.body.json, to: MeetupMutationDTO.self).meetup
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }
}

struct InMemoryMeetupRepository: MeetupRepository, MeetupLiveTransport {
    var meetups: [Meetup] = []
    /// When set, every write throws it — previews stay nil, tests surface it.
    var failure: ViaError? = nil

    func list() async throws -> MeetupListing {
        MeetupListing(meetups: meetups, pendingInvitations: [])
    }
    func load(meetupId: String) async throws -> Meetup {
        guard let meetup = meetups.first(where: { $0.id == meetupId }) else {
            throw ViaError.unavailable
        }
        return meetup
    }
    func create(
        destination: MeetupStation,
        targetArrivalAt: Date,
        organizerDisplayName: String,
        origin: MeetupOrigin,
        shareLevel: MeetupShareLevel
    ) async throws -> Meetup { throw failure ?? ViaError.unavailable }
    func mutate(meetupId: String, change: MeetupChange) async throws -> Meetup {
        if let failure { throw failure }
        let meetup = try await load(meetupId: meetupId)
        switch change {
        case .update(let destination, let targetArrivalAt):
            return meetup.replacing(destination: destination, targetArrivalAt: targetArrivalAt)
        case .configure(_, let shareLevel, let zone):
            return meetup.replacing(participants: meetup.participants.map { participant in
                participant.id == meetup.currentParticipantId
                    ? participant.replacing(shareLevel: shareLevel, zone: zone)
                    : participant
            })
        case .cancel:
            return meetup.replacing(phase: .cancelled)
        case .revokeInvitation(let id):
            return meetup.replacing(
                invitations: meetup.invitations?.map { $0.id == id ? $0.revoked : $0 }
            )
        case .removeParticipant(let id):
            return meetup.replacing(participants: meetup.participants.filter { $0.id != id })
        }
    }
    func invitation(meetupId: String, invitedUserId: String?) async throws -> MeetupInvitationLink { throw failure ?? ViaError.unavailable }
    func previewInvitation(token: String) async throws -> MeetupInvitationPreview { throw ViaError.unavailable }
    func acceptInvitation(token: String, groupKey: String?, displayName: String, origin: MeetupOrigin, shareLevel: MeetupShareLevel) async throws -> Meetup { throw failure ?? ViaError.unavailable }
    func declineInvitation(token: String) async throws {
        if let failure { throw failure }
    }
    func leave(meetupId: String) async throws {
        if let failure { throw failure }
    }
    func publish(meetupId: String, progress: MeetupProgress?, presence: MeetupEncryptedPresence?) async throws -> Int { 0 }
    func poll(meetupId: String, sinceRevision: Int) async throws -> MeetupLiveSnapshot {
        .init(revision: sinceRevision, changed: false, meetup: nil, participants: [])
    }
    func registerActivity(meetupId: String, installationId: String, activityId: String, token: String, environment: APNsEnvironment) async throws {}
    func unregisterActivity(meetupId: String, installationId: String, activityId: String) async throws {}
    func synchronizeGroupKey(for meetup: Meetup) async throws {}
}

private extension Meetup {
    func replacing(
        destination: MeetupStation? = nil,
        targetArrivalAt: Date? = nil,
        phase: MeetupPhase? = nil,
        participants: [MeetupParticipant]? = nil,
        invitations: [MeetupInvitation]? = nil
    ) -> Meetup {
        Meetup(
            id: id,
            destination: destination ?? self.destination,
            targetArrivalAt: targetArrivalAt ?? self.targetArrivalAt,
            phase: phase ?? self.phase,
            revision: revision,
            keyRevision: keyRevision,
            currentParticipantId: currentParticipantId,
            isOrganizer: isOrganizer,
            participants: participants ?? self.participants,
            plan: plan,
            invitations: invitations ?? self.invitations,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private extension MeetupParticipant {
    func replacing(
        shareLevel: MeetupShareLevel? = nil,
        zone: MeetupZone? = nil
    ) -> MeetupParticipant {
        MeetupParticipant(
            id: id,
            displayName: displayName,
            role: role,
            state: state,
            shareLevel: shareLevel ?? self.shareLevel,
            zone: zone ?? self.zone,
            firstBoardingStation: firstBoardingStation,
            departureAt: departureAt,
            arrivalAt: arrivalAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private extension MeetupInvitation {
    var revoked: MeetupInvitation {
        MeetupInvitation(
            id: id,
            status: .revoked,
            invitedUserId: invitedUserId,
            expiresAt: expiresAt,
            createdAt: createdAt
        )
    }
}

private struct MeetupListResponseDTO: Decodable {
    let meetups: [Meetup]
    let pendingInvitations: [MeetupPendingInvitation]
}
private struct MeetupCreateResponseDTO: Decodable { let meetup: Meetup; let participantToken: String }
private struct MeetupMutationDTO: Decodable { let meetup: Meetup }
private struct MeetupAcceptResponseDTO: Decodable {
    let meetup: Meetup
    let participantToken: String
}
private struct MeetupInvitationCreateResponseDTO: Decodable {
    let invitation: MeetupInvitation
    let token: String
    let url: String
}
private struct MeetupPublishResponseDTO: Decodable { let revision: Int }
private struct MeetupPollResponseDTO: Decodable {
    let revision: Int
    let changed: Bool
    let meetup: Meetup?
    let live: [MeetupLiveParticipant]
}

private struct MeetupCreateRequestDTO: Encodable {
    let destination: MeetupStation
    let targetArrivalAt: Date
    let organizerDisplayName: String
    let origin: MeetupOrigin
    let shareLevel: MeetupShareLevel
    let publicKey: String
    let idempotencyKey: String
}
private struct MeetupUpdateRequestDTO: Encodable {
    let meetupId: String
    let destination: MeetupStation?
    let targetArrivalAt: Date?
}
private struct MeetupInvitationCreateRequestDTO: Encodable {
    let meetupId: String
    let invitedUserId: String?
    let keyEnvelopes: [MeetupKeyEnvelope]
    let idempotencyKey: String
}
private struct MeetupInvitationAcceptRequestDTO: Encodable {
    let token: String
    let displayName: String
    let origin: MeetupOrigin
    let shareLevel: MeetupShareLevel
    let publicKey: String
    let keyId: String
    let idempotencyKey: String
}
private struct MeetupConfigureRequestDTO: Encodable {
    let meetupId: String
    let origin: MeetupOrigin?
    let shareLevel: MeetupShareLevel?
    let zone: MeetupZone?
}
private struct MeetupPublishRequestDTO: Encodable {
    let meetupId: String
    let progress: MeetupProgress?
    let presence: MeetupEncryptedPresence?
}
private struct MeetupEnvelopeUploadDTO: Encodable {
    let meetupId: String
    let keyRevision: Int
    let envelopes: [MeetupKeyEnvelope]
}

private extension Sequence {
    func asyncMap<T: Sendable>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values: [T] = []
        for element in self { values.append(try await transform(element)) }
        return values
    }
}
