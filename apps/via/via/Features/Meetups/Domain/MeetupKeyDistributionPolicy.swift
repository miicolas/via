import Foundation

struct MeetupKeyDistributionDecision: Sendable, Equatable {
    let createsGroupKey: Bool
    let recipients: [MeetupDeviceKey]
}

enum MeetupKeyDistributionPolicy {
    static func decision(
        hasCurrentKey: Bool,
        sync: MeetupKeySync
    ) -> MeetupKeyDistributionDecision? {
        if !hasCurrentKey {
            // Existing envelopes establish that another organizer installation
            // already selected the key for this revision. Wait for that key to
            // be enveloped to this installation instead of forking it.
            guard sync.canRotate, sync.envelopes.isEmpty else { return nil }
            return MeetupKeyDistributionDecision(
                createsGroupKey: true,
                recipients: sync.deviceKeys
            )
        }

        guard sync.canRotate else { return nil }
        let coveredKeyIds = Set(sync.envelopes.map(\.recipientKeyId))
        let missing = sync.deviceKeys.filter { !coveredKeyIds.contains($0.keyId) }
        guard !missing.isEmpty else { return nil }
        return MeetupKeyDistributionDecision(
            createsGroupKey: false,
            recipients: missing
        )
    }
}
