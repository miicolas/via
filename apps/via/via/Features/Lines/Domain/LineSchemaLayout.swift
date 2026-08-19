import Foundation

/// Flattens one direction of a line into display rows: sections become titled
/// strips, healthy stretches collapse into "⋯ N gares" runs, and active
/// disruptions tint the segments they cut. Pure and synchronous so the rules
/// stay unit-testable away from SwiftUI.
enum LineSchemaLayout {
    /// How the rail is drawn on one side of a stop row.
    enum RailStyle: Hashable {
        /// No rail: the strip starts or ends here.
        case none
        /// The line's own color, service running.
        case line
        /// Inside an active cut of this severity.
        case cut(LineCondition)
    }

    struct StopRow: Hashable {
        let stop: LineSchemaStop
        /// First or last stop of its section: a terminus or a fork.
        let isSectionEnd: Bool
        /// Worst active disruption touching this stop; nil when unaffected.
        let condition: LineCondition?
        let railAbove: RailStyle
        let railBelow: RailStyle
    }

    struct CollapsedRun: Hashable {
        let id: String
        let hiddenCount: Int
    }

    enum Row: Identifiable, Hashable {
        case sectionHeader(id: String, title: String)
        case stop(StopRow)
        case collapsedRun(CollapsedRun)

        var id: String {
            switch self {
            case .sectionHeader(let id, _): id
            case .stop(let row): row.stop.id
            case .collapsedRun(let run): run.id
            }
        }
    }

    static func rows(
        for direction: LineDirection,
        disruptions: [LineDisruption],
        expandedRunIDs: Set<String>
    ) -> [Row] {
        let marks = projectedMarks(for: direction, disruptions: disruptions)
        var rows: [Row] = []

        for (sectionIndex, section) in direction.sections.enumerated() {
            guard !section.stops.isEmpty else { continue }
            if let label = section.label {
                rows.append(.sectionHeader(id: "header-\(direction.id)-\(sectionIndex)", title: label))
            }

            let sectionMarks = marks[sectionIndex]
            let lastIndex = section.stops.count - 1
            let visible = visibleIndexes(section: section, marks: sectionMarks)

            var index = 0
            while index <= lastIndex {
                if visible.contains(index) {
                    rows.append(.stop(stopRow(
                        section: section,
                        marks: sectionMarks,
                        index: index,
                        lastIndex: lastIndex
                    )))
                    index += 1
                    continue
                }

                var runEnd = index
                while runEnd + 1 <= lastIndex, !visible.contains(runEnd + 1) { runEnd += 1 }
                let runID = "run-\(direction.id)-\(section.stops[index].id)-\(section.stops[runEnd].id)"
                if expandedRunIDs.contains(runID) {
                    for expanded in index...runEnd {
                        rows.append(.stop(stopRow(
                            section: section,
                            marks: sectionMarks,
                            index: expanded,
                            lastIndex: lastIndex
                        )))
                    }
                } else {
                    rows.append(.collapsedRun(CollapsedRun(id: runID, hiddenCount: runEnd - index + 1)))
                }
                index = runEnd + 1
            }
        }
        return rows
    }

    // MARK: - Disruption projection

    /// Cut severity per inter-stop segment and per stop, one entry per section.
    private struct SectionMarks {
        /// Index `i` covers the segment between stops `i` and `i + 1`.
        var segments: [LineCondition?]
        var stops: [LineCondition?]

        init(stopCount: Int) {
            segments = Array(repeating: nil, count: max(stopCount - 1, 0))
            stops = Array(repeating: nil, count: stopCount)
        }
    }

    private static func projectedMarks(
        for direction: LineDirection,
        disruptions: [LineDisruption]
    ) -> [SectionMarks] {
        var marks = direction.sections.map { SectionMarks(stopCount: $0.stops.count) }

        var location: [String: (section: Int, stop: Int)] = [:]
        for (sectionIndex, section) in direction.sections.enumerated() {
            for (stopIndex, stop) in section.stops.enumerated()
            where location[stop.id] == nil {
                location[stop.id] = (sectionIndex, stopIndex)
            }
        }

        for disruption in disruptions where disruption.isActive {
            for cut in disruption.impactedSections {
                guard var from = location[cut.fromStopID], var to = location[cut.toStopID] else {
                    continue
                }
                if (from.section, from.stop) > (to.section, to.stop) { swap(&from, &to) }

                if from.section == to.section {
                    mark(
                        &marks[from.section],
                        stops: from.stop...to.stop,
                        segments: from.stop..<to.stop,
                        as: disruption.condition
                    )
                    continue
                }

                // The cut crosses sections: only the sections carrying the
                // trains that run from one endpoint to the other are on its
                // path — a parallel branch sitting between them in render
                // order is not.
                let fromSection = direction.sections[from.section]
                let toSection = direction.sections[to.section]
                let pathOrigins = Set(fromSection.origins).intersection(toSection.origins)
                let pathTermini = Set(fromSection.termini).intersection(toSection.termini)
                guard !pathOrigins.isEmpty, !pathTermini.isEmpty else { continue }

                let fromLast = fromSection.stops.count - 1
                mark(
                    &marks[from.section],
                    stops: from.stop...fromLast,
                    segments: from.stop..<fromLast,
                    as: disruption.condition
                )
                mark(
                    &marks[to.section],
                    stops: 0...to.stop,
                    segments: 0..<to.stop,
                    as: disruption.condition
                )
                for between in (from.section + 1)..<to.section {
                    let section = direction.sections[between]
                    guard Set(section.origins).isSuperset(of: pathOrigins),
                          Set(section.termini).isSuperset(of: pathTermini),
                          !section.stops.isEmpty else { continue }
                    mark(
                        &marks[between],
                        stops: 0...(section.stops.count - 1),
                        segments: 0..<(section.stops.count - 1),
                        as: disruption.condition
                    )
                }
            }
        }
        return marks
    }

    private static func mark(
        _ marks: inout SectionMarks,
        stops: ClosedRange<Int>,
        segments: Range<Int>,
        as condition: LineCondition
    ) {
        for index in stops {
            marks.stops[index] = worst(marks.stops[index], condition)
        }
        for index in segments {
            marks.segments[index] = worst(marks.segments[index], condition)
        }
    }

    private static func worst(_ current: LineCondition?, _ new: LineCondition) -> LineCondition {
        guard let current else { return new }
        return current.severityRank >= new.severityRank ? current : new
    }

    // MARK: - Collapse rules

    /// What always stays on screen: section endpoints (termini and forks),
    /// interchanges, disrupted stops and one healthy neighbour on each side.
    private static func visibleIndexes(section: LineSchemaSection, marks: SectionMarks) -> Set<Int> {
        var visible: Set<Int> = [0, section.stops.count - 1]
        for (index, stop) in section.stops.enumerated() {
            if stop.isInterchange { visible.insert(index) }
            if marks.stops[index] != nil {
                visible.insert(index)
                if index > 0 { visible.insert(index - 1) }
                if index < section.stops.count - 1 { visible.insert(index + 1) }
            }
        }
        return visible
    }

    private static func stopRow(
        section: LineSchemaSection,
        marks: SectionMarks,
        index: Int,
        lastIndex: Int
    ) -> StopRow {
        StopRow(
            stop: section.stops[index],
            isSectionEnd: index == 0 || index == lastIndex,
            condition: marks.stops[index],
            railAbove: index == 0 ? .none : rail(marks.segments[index - 1]),
            railBelow: index == lastIndex ? .none : rail(marks.segments[index])
        )
    }

    private static func rail(_ condition: LineCondition?) -> RailStyle {
        condition.map(RailStyle.cut) ?? .line
    }
}
