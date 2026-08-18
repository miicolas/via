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

struct LineDetail: Sendable, Hashable {
    let route: RouteBadge
    let branches: [LineBranch]
    let source: LineStatusBoard.Source
    let fetchedAt: Date?
    /// Active disruptions first, then upcoming ones by start time.
    let disruptions: [LineDisruption]

    var activeDisruptions: [LineDisruption] { disruptions.filter(\.isActive) }
    var upcomingDisruptions: [LineDisruption] { disruptions.filter { !$0.isActive } }

    /// The worst active condition, for the detail header badge.
    var condition: LineCondition {
        activeDisruptions.map(\.condition).max { severityRank($0) < severityRank($1) } ?? .normal
    }
}

private func severityRank(_ condition: LineCondition) -> Int {
    switch condition {
    case .normal: 0
    case .attention: 1
    case .disrupted: 2
    case .suspended: 3
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
