import Foundation

protocol MeetupCredentialStoring: Sendable {
    func credential(for meetupId: String) async throws -> MeetupParticipantCredential?
    func allCredentials() async throws -> [MeetupParticipantCredential]
    func store(_ credential: MeetupParticipantCredential) async throws
    func remove(meetupId: String) async throws
}

actor MeetupCredentialVault: MeetupCredentialStoring {
    private let service = "dev.via.app.meetup-capabilities"
    private let defaults: UserDefaults
    private let indexKey = "meetup.credential-index"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func credential(for meetupId: String) throws -> MeetupParticipantCredential? {
        guard let data = try KeychainMeetupSecrets.read(service: service, account: meetupId)
        else { return nil }
        if let credential = try? JSONDecoder.via.decode(MeetupParticipantCredential.self, from: data) {
            return credential
        }
        // One-time migration from the first capability-only Keychain value.
        guard let token = String(data: data, encoding: .utf8) else { return nil }
        return MeetupParticipantCredential(meetupId: meetupId, participantToken: token)
    }

    func allCredentials() throws -> [MeetupParticipantCredential] {
        try (defaults.stringArray(forKey: indexKey) ?? []).compactMap { id in
            try credential(for: id)
        }
    }

    func store(_ credential: MeetupParticipantCredential) throws {
        try KeychainMeetupSecrets.write(
            try JSONEncoder.via.encode(credential),
            service: service,
            account: credential.meetupId
        )
        var ids = Set(defaults.stringArray(forKey: indexKey) ?? [])
        ids.insert(credential.meetupId)
        defaults.set(ids.sorted(), forKey: indexKey)
    }

    func remove(meetupId: String) throws {
        try KeychainMeetupSecrets.delete(service: service, account: meetupId)
        let ids = (defaults.stringArray(forKey: indexKey) ?? []).filter { $0 != meetupId }
        defaults.set(ids, forKey: indexKey)
    }
}
