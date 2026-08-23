import Foundation

struct StationElevator: Sendable, Hashable, Identifiable {
    enum Status: String, Sendable, Hashable {
        case available
        case unavailable = "notavailable"
        case unknown
    }

    enum Reason: String, Sendable, Hashable {
        case failure = "liftFailure"
        case maintenance = "closedForMaintenance"
        case equipmentProblem = "undefinedEquipmentProblem"
    }

    let id: String
    let status: Status
    let reason: Reason?
    let situation: String?
    let direction: String?
    let updatedAt: Date?
}

struct StationElevatorSnapshot: Sendable, Hashable {
    enum SourceStatus: String, Sendable, Hashable {
        case ok
        case unavailable
    }

    let status: SourceStatus
    let sourceUpdatedAt: Date?
    let importedAt: Date?
    let items: [StationElevator]

    static let unavailable = Self(
        status: .unavailable,
        sourceUpdatedAt: nil,
        importedAt: nil,
        items: []
    )
}
