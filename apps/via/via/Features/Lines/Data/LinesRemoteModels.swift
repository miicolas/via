import Foundation

struct LineStatusBoardDTO: Decodable {
    struct Line: Decodable {
        let route: RouteBadgeDTO
        let condition: String
        let summary: String?
        let activeCount: Int
        let upcoming: Upcoming?
    }

    struct Upcoming: Decodable {
        let beginsAt: Date
        let title: String?
    }

    let source: String
    let fetchedAt: Date?
    let lines: [Line]

    func domain() throws -> LineStatusBoard {
        guard let source = LineStatusBoard.Source(rawValue: source) else {
            throw ViaError.decoding
        }
        return LineStatusBoard(
            source: source,
            fetchedAt: fetchedAt,
            lines: try lines.map { line in
                guard let condition = LineCondition(rawValue: line.condition) else {
                    throw ViaError.decoding
                }
                return LineStatus(
                    route: try line.route.domain(),
                    condition: condition,
                    summary: line.summary,
                    activeCount: line.activeCount,
                    upcoming: line.upcoming.map {
                        UpcomingClosure(beginsAt: $0.beginsAt, title: $0.title)
                    }
                )
            }
        )
    }
}

struct LineDetailDTO: Decodable {
    struct Branch: Decodable {
        let id: String
        let directionId: Int
        let headsign: String
        let isCanonical: Bool
        let stops: [Stop]
    }

    struct Stop: Decodable {
        let id: String
        let name: String
    }

    struct Direction: Decodable {
        let directionId: Int
        let label: String
        let sections: [SchemaSection]
    }

    struct SchemaSection: Decodable {
        let role: String
        let label: String?
        let origins: [String]
        let termini: [String]
        let stops: [SchemaStop]
    }

    struct SchemaStop: Decodable {
        let id: String
        let name: String
        let isInterchange: Bool
    }

    struct Disruption: Decodable {
        let id: String
        let severity: String
        let activity: String
        let cause: String?
        let title: String?
        let message: String?
        let periods: [Period]
        let impactedSections: [Section]
        let updatedAt: Date?
    }

    struct Period: Decodable {
        let beginsAt: Date
        let endsAt: Date
    }

    struct Section: Decodable {
        let fromStopId: String
        let fromName: String
        let toStopId: String
        let toName: String
    }

    let route: RouteBadgeDTO
    let branches: [Branch]
    let directions: [Direction]
    let source: String
    let fetchedAt: Date?
    let disruptions: [Disruption]

    func domain() throws -> LineDetail {
        guard let source = LineStatusBoard.Source(rawValue: source) else {
            throw ViaError.decoding
        }
        return LineDetail(
            route: try route.domain(),
            branches: branches.map { branch in
                LineBranch(
                    id: branch.id,
                    directionId: branch.directionId,
                    headsign: branch.headsign,
                    isCanonical: branch.isCanonical,
                    stops: branch.stops.map { LineStop(id: $0.id, name: $0.name) }
                )
            },
            directions: try directions.map { direction in
                LineDirection(
                    id: "direction-\(direction.directionId)",
                    directionId: direction.directionId,
                    label: direction.label,
                    sections: try direction.sections.map { section in
                        guard let role = LineSchemaSection.Role(rawValue: section.role) else {
                            throw ViaError.decoding
                        }
                        return LineSchemaSection(
                            role: role,
                            label: section.label,
                            origins: section.origins,
                            termini: section.termini,
                            stops: section.stops.map {
                                LineSchemaStop(id: $0.id, name: $0.name, isInterchange: $0.isInterchange)
                            }
                        )
                    }
                )
            },
            source: source,
            fetchedAt: fetchedAt,
            disruptions: try disruptions.map { disruption in
                guard let condition = LineCondition(rawValue: disruption.severity) else {
                    throw ViaError.decoding
                }
                return LineDisruption(
                    id: disruption.id,
                    condition: condition,
                    isActive: disruption.activity == "active",
                    cause: disruption.cause,
                    title: disruption.title,
                    message: disruption.message,
                    periods: disruption.periods.map {
                        LineDisruptionPeriod(beginsAt: $0.beginsAt, endsAt: $0.endsAt)
                    },
                    impactedSections: disruption.impactedSections.map {
                        LineImpactedSection(
                            fromStopID: $0.fromStopId,
                            fromName: $0.fromName,
                            toStopID: $0.toStopId,
                            toName: $0.toName
                        )
                    },
                    updatedAt: disruption.updatedAt
                )
            }
        )
    }
}
