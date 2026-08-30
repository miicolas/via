import Foundation

/// One branch strip of a line: a curated pattern with its stops in travel
/// order. The canonical pattern of each direction is the main trunk.
struct LineBranch: Identifiable, Sendable, Hashable {
    let id: String
    let directionId: Int
    /// The terminus label riders know the branch by.
    let headsign: String
    let isCanonical: Bool
    let stops: [LineStop]
}

struct LineStop: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
}

/// A cut segment; stop ids resolve against the branches' stops.
struct LineImpactedSection: Sendable, Hashable {
    let fromStopID: String
    let fromName: String
    let toStopID: String
    let toName: String
}

struct LineDisruptionPeriod: Sendable, Hashable {
    let beginsAt: Date
    let endsAt: Date
}

struct LineDisruption: Identifiable, Sendable, Hashable {
    let id: String
    let condition: LineCondition
    let isActive: Bool
    let cause: String?
    let title: String?
    let message: String?
    let periods: [LineDisruptionPeriod]
    let impactedSections: [LineImpactedSection]
    let updatedAt: Date?
}

/// A station of the complete line schema.
struct LineSchemaStop: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    /// Served by at least one other metro, RER, Transilien or tram line.
    let isInterchange: Bool

    init(id: String, name: String, isInterchange: Bool = false) {
        self.id = id
        self.name = name
        self.isInterchange = isInterchange
    }
}

/// A run of consecutive stations sharing the same service: the trunk every
/// train of the direction serves, or a named branch.
struct LineSchemaSection: Sendable, Hashable {
    enum Role: String, Sendable {
        case trunk
        case branch
    }

    let role: Role
    /// "Branche Cergy-le-Haut"; nil for the trunk.
    let label: String?
    /// Origin/terminus group stops whose trains call in this section — the
    /// trunk lists every group, a branch only its own. Two sections lie on
    /// one physical path iff their groups intersect on both sides; that is
    /// how a disruption spanning several sections projects onto the schema.
    let origins: [String]
    let termini: [String]
    let stops: [LineSchemaStop]
}

/// One direction of the line, complete: every station merged from all trips
/// at import time, not one mission's calls.
struct LineDirection: Identifiable, Sendable, Hashable {
    let id: String
    let directionId: Int
    /// Real termini riders know the direction by: "Boissy / Marne-la-Vallée".
    let label: String
    /// Sections in travel order: origin branches, trunk, destination branches.
    let sections: [LineSchemaSection]
}

struct LineDetail: Sendable, Hashable {
    let route: RouteBadge
    /// Legacy strips: one mission's calls per pattern. Only the fallback for
    /// `schemaDirections` until the schema tables are populated server-side.
    let branches: [LineBranch]
    let directions: [LineDirection]
    let source: LineStatusBoard.Source
    let fetchedAt: Date?
    /// Active disruptions first, then upcoming ones by start time.
    let disruptions: [LineDisruption]

    var activeDisruptions: [LineDisruption] { disruptions.filter(\.isActive) }
    var upcomingDisruptions: [LineDisruption] { disruptions.filter { !$0.isActive } }

    /// The worst active condition, for the detail header badge.
    var condition: LineCondition {
        activeDisruptions.map(\.condition).max { $0.severityRank < $1.severityRank } ?? .normal
    }

    /// The schema the screen draws: the complete merged directions, degrading
    /// to the legacy branch strips while the server tables are still empty.
    var schemaDirections: [LineDirection] {
        if !directions.isEmpty { return directions }
        return branches.map { branch in
            LineDirection(
                id: "branch-\(branch.id)",
                directionId: branch.directionId,
                label: branch.headsign,
                sections: [
                    LineSchemaSection(
                        role: .trunk,
                        label: nil,
                        origins: [],
                        termini: [],
                        stops: branch.stops.map {
                            LineSchemaStop(id: $0.id, name: $0.name)
                        }
                    )
                ]
            )
        }
    }
}

extension LineCondition {
    /// Orders conditions from healthy to blocking, for worst-of reductions.
    var severityRank: Int {
        switch self {
        case .normal: 0
        case .attention: 1
        case .disrupted: 2
        case .suspended: 3
        }
    }
}

extension LineBranch {
    /// Which inter-station segments of this branch are inside a cut section:
    /// index `i` covers the segment between stops `i` and `i + 1`. Sections
    /// are matched regardless of travel direction, since a cut reads the same
    /// both ways.
    func cutSegmentIndexes(for disruptions: [LineDisruption]) -> Set<Int> {
        let indexByStopID = Dictionary(
            stops.enumerated().map { ($0.element.id, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )

        var segments: Set<Int> = []
        for disruption in disruptions where disruption.isActive {
            for section in disruption.impactedSections {
                guard let fromIndex = indexByStopID[section.fromStopID],
                      let toIndex = indexByStopID[section.toStopID],
                      fromIndex != toIndex else { continue }
                let range = min(fromIndex, toIndex)..<max(fromIndex, toIndex)
                segments.formUnion(range)
            }
        }
        return segments
    }
}
