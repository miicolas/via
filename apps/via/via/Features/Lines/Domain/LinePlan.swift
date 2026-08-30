import Foundation

/// The plan of a line: one trunk every train runs on, and the named branches
/// that fork off it.
///
/// A direction arrives from the server as sections — runs of stations sharing
/// the same set of services. Drawing those sections end to end is what made
/// the screen unreadable: two branches that run *beside* each other were
/// stacked as though a train went from the last station of one to the first of
/// the next, and a shared stem was a third strip with a title nobody could
/// place. So the sections are regrouped here into strips — the trunk, then one
/// complete branch per terminus, from the fork to its end, each carrying the
/// stem it shares with its neighbour. A rider reads one spine and a handful of
/// named branches; nothing else on the screen has to know what a service group
/// is.
///
/// Pure and synchronous, so the rules stay unit-testable away from SwiftUI.
enum LinePlan {
    /// How the rail is drawn on one side of a stop row.
    ///
    /// The line's own colour is not known here — a plan is the same whatever
    /// badge hangs off it — so the style stays colourless and `timelineStyle`
    /// hands it to the shared rail once the caller supplies the hex.
    enum RailStyle: Hashable {
        /// No rail: the strip starts or ends here.
        case none
        /// The line's own color, service running.
        case line
        /// Inside an active cut of this severity.
        case cut(LineCondition)

        /// The same style expressed in the journey timeline's vocabulary, so
        /// the Lignes tab and a trip are drawn by the one rail.
        func timelineStyle(colorHex: String?) -> JourneyTimelineRailStyle {
            switch self {
            case .none: JourneyTimelineRailStyle.none
            case .line: .line(colorHex: colorHex)
            case .cut(let condition): .cut(condition)
            }
        }
    }

    struct StopRow: Hashable {
        let stop: LineSchemaStop
        /// First or last stop of its strip: a terminus or a fork.
        let isEnd: Bool
        /// Worst active disruption touching this stop; nil when unaffected.
        let condition: LineCondition?
        /// Where a cut starts or ends. A ten-station interruption is one
        /// stretch, not ten warnings: only its two edges carry the pictogram,
        /// the stations in between are held by the dashed rail.
        let isCutEdge: Bool
        let railAbove: RailStyle
        let railBelow: RailStyle

        /// What the station's hole says on the rail.
        ///
        /// A station caught *inside* a suspension is one no train reaches, so
        /// it is struck through. The two edges of that same suspension are
        /// where the trains turn back — they are still served — so they only
        /// take the colour, and keep the pictogram beside their name.
        var mark: JourneyTimelineBeadMark {
            guard let condition else { return .open }
            return condition == .suspended && !isCutEdge
                ? .closed(condition)
                : .warned(condition)
        }
    }

    struct Strip: Identifiable, Hashable {
        enum Role: Hashable {
            /// The spine: drawn open, it is the line itself.
            case trunk
            /// A fork, known by its terminus or shared-stem label.
            case branch(name: String)

            /// Branch rows indent under the spine they fork off.
            var isBranch: Bool { self != .trunk }

            /// The station the branch is known by; nil for the trunk, which is
            /// not a place but the line.
            var name: String? {
                if case .branch(let name) = self { return name }
                return nil
            }
        }

        let id: String
        let role: Role
        let stops: [StopRow]

        /// Worst disruption anywhere on the strip, so a folded branch can say
        /// it is cut without being opened.
        var condition: LineCondition? {
            stops.compactMap(\.condition).max { $0.severityRank < $1.severityRank }
        }
    }

    /// A direction-aware topology or its direction-independent presentation.
    /// Sections always own stations once; edges retain the real merges and
    /// forks. The complete presentation turns those sections into contiguous
    /// paths whose roles explain how branches and loops reconnect.
    struct Diagram: Hashable {
        struct Section: Identifiable, Hashable {
            /// How an independently readable path belongs to the complete
            /// physical line. Branches deliberately carry their junction so
            /// the presentation never has to imply that the preceding row is
            /// connected to them.
            enum Role: Hashable {
                case main
                case branch(name: String, junction: String?)
                case loop(from: String, to: String)
            }

            let id: String
            let lane: Int
            let role: Role
            let stops: [StopRow]

            init(
                id: String,
                lane: Int,
                role: Role = .main,
                stops: [StopRow]
            ) {
                self.id = id
                self.lane = lane
                self.role = role
                self.stops = stops
            }
        }

        struct Edge: Hashable {
            let fromSectionID: String
            let toSectionID: String
            /// The exact physical stations joined by this cross-section rail.
            /// Section ids alone are not enough: a branch can leave from the
            /// middle of the main path, as Saint-Germain does at
            /// Nanterre-Préfecture on RER A.
            let fromStopID: String
            let toStopID: String
            let rail: RailStyle
        }

        let sections: [Section]
        let edges: [Edge]

        static let empty = Diagram(sections: [], edges: [])
    }

    /// The strips of one direction, in reading order: the branches that feed
    /// the trunk, the trunk, then the branches it feeds.
    static func strips(for direction: LineDirection, disruptions: [LineDisruption]) -> [Strip] {
        let sections = direction.sections.filter { !$0.stops.isEmpty }
        guard !sections.isEmpty else { return [] }

        let spine = spineIndex(of: sections)
        var raw = branches(
            in: Array(sections[..<spine]),
            groupedBy: \.origins,
            prefix: "from"
        )
        let trunkIndex = raw.count
        raw.append(RawStrip(id: "trunk", isTrunk: true, stops: sections[spine].stops))
        raw += branches(
            in: Array(sections[(spine + 1)...]),
            groupedBy: \.termini,
            prefix: "to"
        )

        let marks = projected(disruptions: disruptions, onto: raw, trunkIndex: trunkIndex)
        return raw.enumerated().map { index, strip in
            Strip(
                id: strip.id,
                role: role(of: strip, isLeading: index < trunkIndex),
                stops: rows(of: strip, marks: marks[index])
            )
        }
    }

    /// Sections prepared for the always-expanded platform-display diagram.
    ///
    /// `strips` deliberately repeats a shared stem in every end-to-end service
    /// path. That was useful while each branch folded independently, but a
    /// complete schematic must draw a physical station once. The diagram uses
    /// the server's physical sections and borrows disruption marks from every
    /// service path that traverses each section.
    static func diagramStrips(
        for direction: LineDirection,
        disruptions: [LineDisruption]
    ) -> [Strip] {
        let sections = direction.sections.filter { !$0.stops.isEmpty }
        guard !sections.isEmpty else { return [] }

        let serviceStrips = strips(for: direction, disruptions: disruptions)
        let spine = spineIndex(of: sections)

        return sections.enumerated().map { index, section in
            Strip(
                id: "section-\(index)",
                role: section.role == .trunk
                    ? .trunk
                    : .branch(name: branchName(section, isLeading: index < spine)),
                stops: diagramRows(for: section, from: serviceStrips)
            )
        }
    }

    /// Builds the actual line graph instead of placing section cards one after
    /// another. Every service group contributes one path through the ordered
    /// sections, which produces the exact shared stems, merges and forks.
    static func diagram(
        for direction: LineDirection,
        disruptions: [LineDisruption]
    ) -> Diagram {
        let sourceSections = direction.sections.filter { !$0.stops.isEmpty }
        guard !sourceSections.isEmpty else { return .empty }

        let spine = spineIndex(of: sourceSections)
        let strips = diagramStrips(for: direction, disruptions: disruptions)
        let serviceStrips = self.strips(for: direction, disruptions: disruptions)
        let originLanes = laneMap(sourceSections[spine].origins)
        let terminusLanes = laneMap(sourceSections[spine].termini)

        var edgeIndexes: Set<SectionEdge> = []
        for group in sourceSections[spine].origins {
            connectConsecutive(
                sourceSections.indices.filter {
                    $0 <= spine && sourceSections[$0].origins.contains(group)
                },
                into: &edgeIndexes
            )
        }
        for group in sourceSections[spine].termini {
            connectConsecutive(
                sourceSections.indices.filter {
                    $0 >= spine && sourceSections[$0].termini.contains(group)
                },
                into: &edgeIndexes
            )
        }

        let incoming = Dictionary(grouping: edgeIndexes, by: \.to).mapValues(\.count)
        let outgoing = Dictionary(grouping: edgeIndexes, by: \.from).mapValues(\.count)
        let sections = strips.enumerated().map { index, strip in
            let sectionRole: Diagram.Section.Role = switch strip.role {
            case .trunk:
                .main
            case .branch(let name):
                .branch(name: name, junction: nil)
            }
            return Diagram.Section(
                id: strip.id,
                lane: lane(
                    for: sourceSections[index],
                    at: index,
                    spine: spine,
                    originLanes: originLanes,
                    terminusLanes: terminusLanes
                ),
                role: sectionRole,
                stops: strip.stops.enumerated().map { stopIndex, row in
                    StopRow(
                        stop: row.stop,
                        isEnd: (stopIndex == 0 && incoming[index] == nil)
                            || (stopIndex == strip.stops.count - 1 && outgoing[index] == nil),
                        condition: row.condition,
                        isCutEdge: row.isCutEdge,
                        railAbove: row.railAbove,
                        railBelow: row.railBelow
                    )
                }
            )
        }

        let edges = edgeIndexes
            .sorted { ($0.from, $0.to) < ($1.from, $1.to) }
            .map { edge in
                Diagram.Edge(
                    fromSectionID: sections[edge.from].id,
                    toSectionID: sections[edge.to].id,
                    fromStopID: sourceSections[edge.from].stops.last!.id,
                    toStopID: sourceSections[edge.to].stops.first!.id,
                    rail: diagramRail(
                        from: sourceSections[edge.from].stops.last!.id,
                        to: sourceSections[edge.to].stops.first!.id,
                        in: serviceStrips
                    )
                )
            }
        return Diagram(sections: sections, edges: edges)
    }

    private struct SectionEdge: Hashable {
        let from: Int
        let to: Int
    }

    private static func connectConsecutive(_ indexes: [Int], into edges: inout Set<SectionEdge>) {
        for pair in zip(indexes, indexes.dropFirst()) {
            edges.insert(SectionEdge(from: pair.0, to: pair.1))
        }
    }

    private static func laneMap(_ groups: [String]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: groups.enumerated().map { ($0.element, $0.offset) })
    }

    private static func lane(
        for section: LineSchemaSection,
        at index: Int,
        spine: Int,
        originLanes: [String: Int],
        terminusLanes: [String: Int]
    ) -> Int {
        guard index != spine else { return 0 }
        let groups = index < spine ? section.origins : section.termini
        let lanes = index < spine ? originLanes : terminusLanes
        return groups.compactMap { lanes[$0] }.min() ?? 0
    }

    // MARK: - Regrouping sections into strips

    private struct RawStrip {
        let id: String
        let isTrunk: Bool
        let stops: [LineSchemaStop]
    }

    /// The section the plan hangs off: the one every service runs through.
    ///
    /// A feed that names no trunk — a genuine spiderweb like the H, or a
    /// server that has not rebuilt its schema yet — still has a core: the
    /// stretch the most services share. Falling back to that beats falling
    /// back to the longest branch, which would hang the whole line off one of
    /// its ends.
    private static func spineIndex(of sections: [LineSchemaSection]) -> Int {
        if let trunk = sections.firstIndex(where: { $0.role == .trunk }) { return trunk }
        let widest = sections.indices.max { left, right in
            let counts = (
                sections[left].origins.count + sections[left].termini.count,
                sections[right].origins.count + sections[right].termini.count
            )
            guard counts.0 == counts.1 else { return counts.0 < counts.1 }
            let stops = (sections[left].stops.count, sections[right].stops.count)
            // Ties go to the earlier section, so the plan never reshuffles.
            return stops.0 == stops.1 ? left > right : stops.0 < stops.1
        }
        return widest ?? sections.startIndex
    }

    /// One strip per service group, each holding every section its trains run
    /// through — which is what puts a shared stem at the head of both branches
    /// it serves, exactly as a rider sees it from the platform.
    private static func branches(
        in sections: [LineSchemaSection],
        groupedBy groups: KeyPath<LineSchemaSection, [String]>,
        prefix: String
    ) -> [RawStrip] {
        guard !sections.isEmpty else { return [] }

        var keys: [String] = []
        for section in sections {
            for key in section[keyPath: groups] where !keys.contains(key) { keys.append(key) }
        }
        // A single group — or a feed that names none — is one branch, not a
        // fork: everything before or after the trunk is the same strip.
        guard keys.count > 1 else {
            return [RawStrip(id: prefix, isTrunk: false, stops: sections.flatMap(\.stops))]
        }

        var strips: [RawStrip] = []
        var seen: Set<[String]> = []
        for key in keys {
            let stops = sections
                .filter { $0[keyPath: groups].contains(key) }
                .flatMap(\.stops)
            guard !stops.isEmpty, seen.insert(stops.map(\.id)).inserted else { continue }
            strips.append(RawStrip(id: "\(prefix)-\(key)", isTrunk: false, stops: stops))
        }
        return strips
    }

    /// A branch is known by its far end: the station its trains start from, or
    /// the one they end at. Every branch is regrouped from at least one
    /// non-empty section, so that far end is always there.
    private static func role(of strip: RawStrip, isLeading: Bool) -> Strip.Role {
        guard !strip.isTrunk else { return .trunk }
        let end = isLeading ? strip.stops.first : strip.stops.last
        return .branch(name: end?.name ?? "")
    }

    private static func branchName(_ section: LineSchemaSection, isLeading: Bool) -> String {
        if let label = section.label {
            return label
                .replacingOccurrences(of: "Branches ", with: "")
                .replacingOccurrences(of: "Branche ", with: "")
        }
        return (isLeading ? section.stops.first : section.stops.last)?.name ?? ""
    }

    // MARK: - Disruption projection

    /// Cut severity per stop and per inter-stop segment, one entry per strip.
    private struct Marks {
        /// Index `i` covers the segment between stops `i` and `i + 1`.
        var segments: [LineCondition?]
        var stops: [LineCondition?]

        init(stopCount: Int) {
            segments = Array(repeating: nil, count: max(stopCount - 1, 0))
            stops = Array(repeating: nil, count: stopCount)
        }
    }

    /// Where a strip sits along the line: the branches feeding the trunk come
    /// before it, the ones it feeds come after. A cut between two zones runs
    /// through everything in between; a cut between two strips of the *same*
    /// zone is two parallel branches, which no train travels between, so it is
    /// left alone.
    private static func projected(
        disruptions: [LineDisruption],
        onto strips: [RawStrip],
        trunkIndex: Int
    ) -> [Marks] {
        var marks = strips.map { Marks(stopCount: $0.stops.count) }
        let zones = strips.indices.map { index in
            index < trunkIndex ? 0 : (index == trunkIndex ? 1 : 2)
        }
        let positions = strips.map { strip in
            Dictionary(
                strip.stops.enumerated().map { ($0.element.id, $0.offset) },
                uniquingKeysWith: { first, _ in first }
            )
        }

        for disruption in disruptions where disruption.isActive {
            for cut in disruption.impactedSections {
                let fromZones = Set(strips.indices.filter { positions[$0][cut.fromStopID] != nil }
                    .map { zones[$0] })
                let toZones = Set(strips.indices.filter { positions[$0][cut.toStopID] != nil }
                    .map { zones[$0] })
                guard !fromZones.isEmpty, !toZones.isEmpty else { continue }

                for index in strips.indices {
                    let last = strips[index].stops.count - 1
                    guard last >= 0 else { continue }
                    let from = positions[index][cut.fromStopID]
                    let to = positions[index][cut.toStopID]

                    switch (from, to) {
                    case (.some(let from), .some(let to)):
                        mark(&marks[index], between: min(from, to), and: max(from, to), as: disruption.condition)
                    case (.some(let end), nil), (nil, .some(let end)):
                        // One end of the cut is on this strip; the zone the
                        // *other* end lives in says which way it runs from here.
                        let farZones = from == nil ? fromZones : toZones
                        guard let side = side(of: farZones, from: zones[index]) else { continue }
                        mark(
                            &marks[index],
                            between: side == .after ? end : 0,
                            and: side == .after ? last : end,
                            as: disruption.condition
                        )
                    case (nil, nil):
                        // Only a strip caught between the two ends is on the
                        // path — in practice the trunk under a cut running from
                        // one branch to another.
                        guard let low = (fromZones.union(toZones)).min(),
                              let high = (fromZones.union(toZones)).max(),
                              low < zones[index], zones[index] < high else { continue }
                        mark(&marks[index], between: 0, and: last, as: disruption.condition)
                    }
                }
            }
        }
        return marks
    }

    private enum Side { case before, after }

    private static func side(of zones: Set<Int>, from zone: Int) -> Side? {
        if zones.contains(where: { $0 > zone }) { return .after }
        if zones.contains(where: { $0 < zone }) { return .before }
        return nil
    }

    private static func mark(
        _ marks: inout Marks,
        between first: Int,
        and last: Int,
        as condition: LineCondition
    ) {
        for index in first...last {
            marks.stops[index] = worst(marks.stops[index], condition)
        }
        for index in first..<last {
            marks.segments[index] = worst(marks.segments[index], condition)
        }
    }

    private static func worst(_ current: LineCondition?, _ new: LineCondition) -> LineCondition {
        guard let current else { return new }
        return current.severityRank >= new.severityRank ? current : new
    }

    // MARK: - Rows

    private static func rows(of strip: RawStrip, marks: Marks) -> [StopRow] {
        let last = strip.stops.count - 1
        return strip.stops.enumerated().map { index, stop in
            let condition = marks.stops[index]
            return StopRow(
                stop: stop,
                isEnd: index == 0 || index == last,
                condition: condition,
                isCutEdge: condition != nil
                    && (index == 0
                        || index == last
                        || marks.stops[index - 1] != condition
                        || marks.stops[index + 1] != condition),
                railAbove: index == 0 ? .none : rail(marks.segments[index - 1]),
                railBelow: index == last ? .none : rail(marks.segments[index])
            )
        }
    }

    private static func diagramRows(for section: LineSchemaSection, from strips: [Strip]) -> [StopRow] {
        let last = section.stops.count - 1
        return section.stops.enumerated().map { index, stop in
            let candidates = strips.flatMap(\.stops).filter { $0.stop.id == stop.id }
            let condition = candidates.compactMap(\.condition)
                .max { $0.severityRank < $1.severityRank }

            return StopRow(
                stop: stop,
                isEnd: index == 0 || index == last,
                condition: condition,
                isCutEdge: candidates.contains(where: \.isCutEdge),
                railAbove: index == 0
                    ? .none
                    : diagramRail(
                        from: section.stops[index - 1].id,
                        to: stop.id,
                        in: strips
                    ),
                railBelow: index == last
                    ? .none
                    : diagramRail(
                        from: stop.id,
                        to: section.stops[index + 1].id,
                        in: strips
                    )
            )
        }
    }

    private static func diagramRail(from firstID: String, to secondID: String, in strips: [Strip]) -> RailStyle {
        let styles = strips.compactMap { strip -> RailStyle? in
            guard let first = strip.stops.firstIndex(where: { $0.stop.id == firstID }),
                  first + 1 < strip.stops.count,
                  strip.stops[first + 1].stop.id == secondID else { return nil }
            return strip.stops[first].railBelow
        }

        return styles.max { left, right in
            railSeverity(left) < railSeverity(right)
        } ?? .line
    }

    private static func railSeverity(_ style: RailStyle) -> Int {
        switch style {
        case .none: -1
        case .line: 0
        case .cut(let condition): condition.severityRank + 1
        }
    }

    private static func rail(_ condition: LineCondition?) -> RailStyle {
        condition.map(RailStyle.cut) ?? .line
    }
}
