import Foundation

struct MeetupStation: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let coordinate: GeoCoordinate

    init(id: String, name: String, coordinate: GeoCoordinate) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
    }

    init(_ station: StationOverview) {
        self.init(id: station.id.rawValue, name: station.name, coordinate: station.coordinate)
    }

    init(_ station: StationSearchResult) {
        self.init(id: station.id.rawValue, name: station.name, coordinate: station.coordinate)
    }
}

struct MeetupOrigin: Codable, Sendable, Hashable {
    enum Kind: String, Codable, Sendable, CaseIterable {
        case currentLocation
        case station
        case address
        case favorite
    }

    let kind: Kind
    let id: String
    let name: String
    let context: String?
    let coordinate: GeoCoordinate

    static func currentLocation(_ coordinate: GeoCoordinate) -> Self {
        Self(
            kind: .currentLocation,
            id: "current-location",
            name: "Ma position",
            context: nil,
            coordinate: coordinate
        )
    }

    init(result: SearchResult, favorite: Bool = false) {
        if favorite {
            kind = .favorite
        } else {
            switch result.kind {
            case .station: kind = .station
            case .address, .bikeStation: kind = .address
            }
        }
        id = result.id
        name = result.name
        context = result.subtitle
        coordinate = result.coordinate
    }

    init(
        kind: Kind,
        id: String,
        name: String,
        context: String?,
        coordinate: GeoCoordinate
    ) {
        self.kind = kind
        self.id = id
        self.name = name
        self.context = context
        self.coordinate = coordinate
    }
}

enum MeetupPhase: String, Codable, Sendable, Hashable {
    case draft, planning, ready, live, completed, cancelled, expired
}

enum MeetupShareLevel: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case positionAndProgress
    case progressOnly
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .positionAndProgress: "Position et progression"
        case .progressOnly: "Progression seule"
        case .off: "Aucun direct"
        }
    }

    var explanation: String {
        switch self {
        case .positionAndProgress:
            "Votre point précis chiffré et votre avancée sont visibles pendant le trajet."
        case .progressOnly:
            "Le groupe voit votre station ou section actuelle, jamais votre point GPS."
        case .off:
            "Seul votre plan statique reste visible."
        }
    }

    var systemImage: String {
        switch self {
        case .positionAndProgress: "location.fill"
        case .progressOnly: "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .off: "eye.slash.fill"
        }
    }
}

enum MeetupParticipantRole: String, Codable, Sendable, Hashable {
    case organizer, member
}

enum MeetupParticipantState: String, Codable, Sendable, Hashable {
    case configuring, ready, underway, joined, arrived, declined, left, removed
}

enum MeetupZone: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case front, middle, rear

    var id: String { rawValue }
    var title: String {
        switch self {
        case .front: "Avant"
        case .middle: "Milieu"
        case .rear: "Arrière"
        }
    }
}

struct MeetupParticipant: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let displayName: String
    let role: MeetupParticipantRole
    let state: MeetupParticipantState
    let shareLevel: MeetupShareLevel
    let zone: MeetupZone
    let firstBoardingStation: MeetupStation?
    let departureAt: Date?
    let arrivalAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

struct MeetupJoinPoint: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let station: MeetupStation
    let serviceId: String
    let meetAt: Date
    let participantIds: [String]
    let zone: MeetupZone
}

struct MeetupParticipantJourney: Codable, Sendable, Hashable {
    let participantId: String
    let departureAt: Date
    let arrivalAt: Date
    let firstBoardingStation: MeetupStation?
    /// The backend only includes the caller's own decrypted journey.
    let journey: Journey?
}

struct MeetupPlan: Codable, Sendable, Hashable {
    enum Status: String, Codable, Sendable {
        case ready, fallbackAtDestination, unavailable
    }

    let revision: Int
    let status: Status
    let generatedAt: Date
    let isStale: Bool
    let warning: String?
    let participantJourneys: [MeetupParticipantJourney]
    let joinPoints: [MeetupJoinPoint]
}

struct MeetupInvitation: Codable, Sendable, Hashable, Identifiable {
    enum Status: String, Codable, Sendable {
        case pending, accepted, declined, revoked, expired
    }

    let id: String
    let status: Status
    let invitedUserId: String?
    let expiresAt: Date
    let createdAt: Date
}

struct Meetup: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let destination: MeetupStation
    let targetArrivalAt: Date
    let phase: MeetupPhase
    let revision: Int
    let keyRevision: Int
    let currentParticipantId: String
    let isOrganizer: Bool
    let participants: [MeetupParticipant]
    let plan: MeetupPlan?
    let invitations: [MeetupInvitation]?
    let createdAt: Date
    let updatedAt: Date

    var currentParticipant: MeetupParticipant? {
        participants.first { $0.id == currentParticipantId }
    }
}

struct MeetupInvitationPreview: Codable, Sendable, Hashable {
    enum Status: String, Codable, Sendable {
        case available, full, expired, revoked
    }

    let organizerDisplayName: String
    let destination: MeetupStation
    let targetArrivalAt: Date
    let status: Status
    let expiresAt: Date
}

enum MeetupProgressStatus: String, Codable, Sendable, Hashable {
    case planned, waiting, underway, missed, joined, arrived, stopped
}

struct MeetupProgress: Codable, Sendable, Hashable {
    let status: MeetupProgressStatus
    let sectionId: String?
    let serviceId: String?
    let station: MeetupStation?
    let expectedAt: Date?
    let updatedAt: Date
}

enum MeetupPresenceFreshness: String, Codable, Sendable, Hashable {
    case live, delayed, stale, offline
}

struct MeetupEncryptedPresence: Codable, Sendable, Hashable {
    let keyRevision: Int
    let ciphertext: String
    let sentAt: Date
}

struct MeetupLiveParticipant: Codable, Sendable, Hashable, Identifiable {
    let participantId: String
    let progress: MeetupProgress?
    let presence: MeetupEncryptedPresence?
    let freshness: MeetupPresenceFreshness

    var id: String { participantId }
}

struct MeetupLiveSnapshot: Sendable, Hashable {
    let revision: Int
    let changed: Bool
    let meetup: Meetup?
    let participants: [MeetupLiveParticipant]
}

struct MeetupPreciseLocation: Codable, Sendable, Hashable {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double?
    let recordedAt: Date

    init(sample: LocationSample) {
        latitude = sample.coordinate.latitude
        longitude = sample.coordinate.longitude
        horizontalAccuracy = sample.horizontalAccuracy
        recordedAt = sample.recordedAt
    }
}

struct MeetupParticipantCredential: Codable, Sendable, Hashable, Identifiable {
    let meetupId: String
    /// Nil for an account-backed participant restored on a new installation.
    /// The authenticated session authorizes that participant instead.
    let participantToken: String?
    let deviceKeyId: String?

    init(meetupId: String, participantToken: String?, deviceKeyId: String? = nil) {
        self.meetupId = meetupId
        self.participantToken = participantToken
        self.deviceKeyId = deviceKeyId
    }

    var id: String { meetupId }
}

struct MeetupDeviceKey: Codable, Sendable, Hashable, Identifiable {
    let keyId: String
    let participantId: String
    let publicKey: String

    var id: String { keyId }
}

struct MeetupKeySync: Codable, Sendable, Hashable {
    struct Envelope: Codable, Sendable, Hashable {
        let recipientKeyId: String
        let keyRevision: Int
        let ciphertext: String
    }

    let keyRevision: Int
    let canRotate: Bool
    let deviceKeys: [MeetupDeviceKey]
    let envelopes: [Envelope]
}

struct MeetupInvitationLink: Sendable, Hashable, Identifiable {
    let id: String
    let url: URL
    let expiresAt: Date
}

struct MeetupPendingInvitation: Codable, Sendable, Hashable, Identifiable {
    let invitation: MeetupInvitation
    let token: String
    let meetupId: String
    let organizerDisplayName: String
    let destination: MeetupStation
    let targetArrivalAt: Date

    var id: String { invitation.id }
}

struct MeetupListing: Sendable, Hashable {
    let meetups: [Meetup]
    let pendingInvitations: [MeetupPendingInvitation]
}
