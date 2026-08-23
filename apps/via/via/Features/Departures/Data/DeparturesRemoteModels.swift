import Foundation

struct DepartureBoardDTO: Decodable {
    struct Item: Decodable {
        let id: String
        let scheduledAt: Date?
        let expectedAt: Date?
        let delaySeconds: Int?
        let status: String
    }

    struct Group: Decodable {
        let route: RouteBadgeDTO
        let destination: String
        let departures: [Date]
        let departureItems: [Item]?
    }

    let source: String
    let generatedAt: Date
    let fetchedAt: Date?
    let peak: PeakDTO?
    let elevators: ElevatorSnapshotDTO?
    let groups: [Group]

    struct PeakDTO: Decodable {
        let ratio: Double
        let level: String
        let label: String
    }

    struct ElevatorSnapshotDTO: Decodable {
        struct Item: Decodable {
            let id: String
            let status: String
            let reason: String?
            let situation: String?
            let direction: String?
            let updatedAt: Date?
        }

        let status: String
        let sourceUpdatedAt: Date?
        let importedAt: Date?
        let items: [Item]

        func domain() throws -> StationElevatorSnapshot {
            guard let sourceStatus = StationElevatorSnapshot.SourceStatus(rawValue: status) else {
                throw ViaError.decoding
            }
            return StationElevatorSnapshot(
                status: sourceStatus,
                sourceUpdatedAt: sourceUpdatedAt,
                importedAt: importedAt,
                items: try items.map { item in
                    guard let itemStatus = StationElevator.Status(rawValue: item.status) else {
                        throw ViaError.decoding
                    }
                    let reason: StationElevator.Reason?
                    if let rawReason = item.reason {
                        guard let parsedReason = StationElevator.Reason(rawValue: rawReason) else {
                            throw ViaError.decoding
                        }
                        reason = parsedReason
                    } else {
                        reason = nil
                    }
                    return StationElevator(
                        id: item.id,
                        status: itemStatus,
                        reason: reason,
                        situation: item.situation,
                        direction: item.direction,
                        updatedAt: item.updatedAt
                    )
                }
            )
        }
    }

    func domain() throws -> DepartureBoard {
        guard let source = DepartureBoard.Source(rawValue: source) else {
            throw ViaError.decoding
        }
        return DepartureBoard(
            source: source,
            generatedAt: generatedAt,
            fetchedAt: fetchedAt,
            peak: peak.flatMap { value in
                guard let level = PeakLevel(rawValue: value.level) else { return nil }
                return StationPeak(ratio: value.ratio, level: level, label: value.label)
            },
            elevators: try elevators?.domain() ?? .unavailable,
            groups: try groups.map {
                let route = try $0.route.domain()
                if let departureItems = $0.departureItems {
                    return DepartureGroup(
                        route: route,
                        destination: $0.destination,
                        departureItems: try departureItems.map { item in
                            guard let status = DepartureStatus(rawValue: item.status) else {
                                throw ViaError.decoding
                            }
                            return DepartureItem(
                                id: item.id,
                                scheduledAt: item.scheduledAt,
                                expectedAt: item.expectedAt,
                                delaySeconds: item.delaySeconds,
                                status: status
                            )
                        }
                    )
                }

                return DepartureGroup(
                    route: route,
                    destination: $0.destination,
                    departures: $0.departures,
                    status: source == .theoretical ? .scheduled : .noReport
                )
            }
        )
    }
}
