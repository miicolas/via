import XCTest
@testable import Via

final class MeetupKeyDistributionPolicyTests: XCTestCase {
    private let organizerKey = MeetupDeviceKey(
        keyId: "organizer-installation",
        participantId: "organizer",
        publicKey: "organizer-public-key"
    )
    private let secondKey = MeetupDeviceKey(
        keyId: "second-installation",
        participantId: "participant",
        publicKey: "participant-public-key"
    )

    func testStartsANewRevisionOnlyWhenNoEnvelopeAlreadyExists() {
        let decision = MeetupKeyDistributionPolicy.decision(
            hasCurrentKey: false,
            sync: sync(envelopes: [])
        )

        XCTAssertEqual(decision?.createsGroupKey, true)
        XCTAssertEqual(decision?.recipients.map(\.keyId), [
            organizerKey.keyId,
            secondKey.keyId,
        ])
    }

    func testFreshOrganizerInstallationWaitsInsteadOfForkingAnExistingRevision() {
        let decision = MeetupKeyDistributionPolicy.decision(
            hasCurrentKey: false,
            sync: sync(envelopes: [envelope(for: organizerKey)])
        )

        XCTAssertNil(decision)
    }

    func testOrganizerWithTheKeyEnvelopesOnlyMissingInstallations() {
        let decision = MeetupKeyDistributionPolicy.decision(
            hasCurrentKey: true,
            sync: sync(envelopes: [envelope(for: organizerKey)])
        )

        XCTAssertEqual(decision?.createsGroupKey, false)
        XCTAssertEqual(decision?.recipients.map(\.keyId), [secondKey.keyId])
    }

    func testParticipantNeverRotatesTheGroupKey() {
        let decision = MeetupKeyDistributionPolicy.decision(
            hasCurrentKey: false,
            sync: sync(canRotate: false, envelopes: [])
        )

        XCTAssertNil(decision)
    }

    private func sync(
        canRotate: Bool = true,
        envelopes: [MeetupKeySync.Envelope]
    ) -> MeetupKeySync {
        MeetupKeySync(
            keyRevision: 4,
            canRotate: canRotate,
            deviceKeys: [organizerKey, secondKey],
            envelopes: envelopes
        )
    }

    private func envelope(for key: MeetupDeviceKey) -> MeetupKeySync.Envelope {
        MeetupKeySync.Envelope(
            recipientKeyId: key.keyId,
            keyRevision: 4,
            ciphertext: "encrypted-group-key"
        )
    }
}
