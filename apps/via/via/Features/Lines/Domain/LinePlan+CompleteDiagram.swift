import Foundation

extension LinePlan {
    /// Builds one direction-independent plan from every schema supplied by
    /// the server.
    ///
    /// Some lines are not the same set of stations read backwards. Metro 10,
    /// for example, has a one-way loop, while a branched RER has several
    /// parallel termini. Selecting one "richest" direction therefore loses
    /// stations, and flattening server sections invents journeys between the
    /// end of one branch and the start of the next. The complete plan first
    /// unions the physical station graph, then decomposes it into contiguous
    /// paths: one longest main path followed by independently labelled
    /// branches and loops. Every consecutive pair shown to the rider is a real
    /// edge, and every physical station is owned by exactly one path.
    static func diagram(
        for directions: [LineDirection],
        disruptions: [LineDisruption]
    ) -> Diagram {
        let orderedDirections = directions.sorted(by: prefersAsReference)
        guard !orderedDirections.isEmpty else { return .empty }

        let graph = CompleteLineGraph(
            directions: orderedDirections,
            disruptions: disruptions
        )
        return graph.diagram()
    }

    private static func prefersAsReference(_ left: LineDirection, _ right: LineDirection) -> Bool {
        let leftCount = Set(left.sections.flatMap(\.stops).map(\.id)).count
        let rightCount = Set(right.sections.flatMap(\.stops).map(\.id)).count
        guard leftCount == rightCount else { return leftCount > rightCount }
        guard left.directionId == right.directionId else {
            return left.directionId < right.directionId
        }
        return left.id < right.id
    }
}

private struct CompleteLineGraph {
    private struct PhysicalEdge: Hashable {
        let first: String
        let second: String

        init(_ first: String, _ second: String) {
            if first < second {
                self.first = first
                self.second = second
            } else {
                self.first = second
                self.second = first
            }
        }
    }

    private struct PathDescriptor {
        let stopIDs: [String]
        let isMain: Bool
        /// Already-owned stations through which this path rejoins the plan.
        let anchors: [String]
    }

    private var stopsByID: [String: LineSchemaStop] = [:]
    private var rowCandidates: [String: [LinePlan.StopRow]] = [:]
    private var adjacency: [String: Set<String>] = [:]
    private var railByEdge: [PhysicalEdge: LinePlan.RailStyle] = [:]
    private var referenceRank: [String: Int] = [:]
    private var referenceSequences: [[String]] = []

    init(directions: [LineDirection], disruptions: [LineDisruption]) {
        for direction in directions {
            let flattened = direction.sections.flatMap { $0.stops.map(\.id) }
            if !flattened.isEmpty { referenceSequences.append(flattened) }
            referenceSequences += direction.sections
                .map { $0.stops.map(\.id) }
                .filter { !$0.isEmpty }

            for stop in direction.sections.flatMap(\.stops) {
                if referenceRank[stop.id] == nil {
                    referenceRank[stop.id] = referenceRank.count
                }
            }

            merge(
                LinePlan.diagram(for: direction, disruptions: disruptions)
            )
        }
    }

    func diagram() -> LinePlan.Diagram {
        let descriptors = pathDescriptors()
        guard !descriptors.isEmpty else { return .empty }

        let sections = descriptors.enumerated().map { index, descriptor in
            LinePlan.Diagram.Section(
                id: "complete-section-\(index)",
                lane: descriptor.isMain ? 0 : 1,
                role: role(for: descriptor),
                stops: rows(for: descriptor.stopIDs)
            )
        }

        let sectionIDByStop = Dictionary(
            uniqueKeysWithValues: zip(descriptors, sections).flatMap { descriptor, section in
                descriptor.stopIDs.map { ($0, section.id) }
            }
        )
        let sectionIndexByID = Dictionary(
            uniqueKeysWithValues: sections.enumerated().map { ($0.element.id, $0.offset) }
        )

        var sectionEdges: Set<LinePlan.Diagram.Edge> = []
        for (physicalEdge, rail) in railByEdge {
            guard let firstSection = sectionIDByStop[physicalEdge.first],
                  let secondSection = sectionIDByStop[physicalEdge.second],
                  firstSection != secondSection else { continue }

            let firstIndex = sectionIndexByID[firstSection] ?? 0
            let secondIndex = sectionIndexByID[secondSection] ?? 0
            sectionEdges.insert(
                LinePlan.Diagram.Edge(
                    fromSectionID: firstIndex < secondIndex ? firstSection : secondSection,
                    toSectionID: firstIndex < secondIndex ? secondSection : firstSection,
                    rail: rail
                )
            )
        }

        return LinePlan.Diagram(
            sections: sections,
            edges: sectionEdges.sorted {
                ($0.fromSectionID, $0.toSectionID) < ($1.fromSectionID, $1.toSectionID)
            }
        )
    }

    // MARK: - Graph construction

    private mutating func merge(_ diagram: LinePlan.Diagram) {
        let sectionByID = Dictionary(uniqueKeysWithValues: diagram.sections.map { ($0.id, $0) })

        for section in diagram.sections {
            for row in section.stops {
                stopsByID[row.stop.id] = stopsByID[row.stop.id] ?? row.stop
                rowCandidates[row.stop.id, default: []].append(row)
                if adjacency[row.stop.id] == nil { adjacency[row.stop.id] = [] }
                if referenceRank[row.stop.id] == nil {
                    referenceRank[row.stop.id] = referenceRank.count
                }
            }

            for pair in zip(section.stops, section.stops.dropFirst()) {
                addEdge(
                    from: pair.0.stop.id,
                    to: pair.1.stop.id,
                    rail: pair.0.railBelow
                )
            }
        }

        for edge in diagram.edges {
            guard let firstID = sectionByID[edge.fromSectionID]?.stops.last?.stop.id,
                  let secondID = sectionByID[edge.toSectionID]?.stops.first?.stop.id else {
                continue
            }
            addEdge(from: firstID, to: secondID, rail: edge.rail)
        }
    }

    private mutating func addEdge(
        from firstID: String,
        to secondID: String,
        rail: LinePlan.RailStyle
    ) {
        guard firstID != secondID else { return }
        let edge = PhysicalEdge(firstID, secondID)
        adjacency[firstID, default: []].insert(secondID)
        adjacency[secondID, default: []].insert(firstID)

        if let current = railByEdge[edge] {
            railByEdge[edge] = railSeverity(current) >= railSeverity(rail) ? current : rail
        } else {
            railByEdge[edge] = rail == .none ? .line : rail
        }
    }

    // MARK: - Path decomposition

    private func pathDescriptors() -> [PathDescriptor] {
        var descriptors: [PathDescriptor] = []
        var assigned: Set<String> = []
        var assignedOrder: [String: Int] = [:]

        for component in connectedComponents(in: Set(stopsByID.keys)) {
            let mainPath = primaryPath(in: component)
            guard !mainPath.isEmpty else { continue }

            let isFirstComponent = descriptors.isEmpty
            descriptors.append(
                PathDescriptor(stopIDs: mainPath, isMain: isFirstComponent, anchors: [])
            )
            assign(mainPath, to: &assigned, order: &assignedOrder)

            while true {
                let remaining = component.subtracting(assigned)
                guard !remaining.isEmpty else { break }

                let components = connectedComponents(in: remaining)
                guard let next = components.min(by: {
                    componentSortKey($0, assignedOrder: assignedOrder)
                        < componentSortKey($1, assignedOrder: assignedOrder)
                }) else { break }

                let descriptor = attachedPath(
                    in: next,
                    assigned: assigned,
                    assignedOrder: assignedOrder
                )
                let path = descriptor.stopIDs.isEmpty
                    ? [ordered(next).first].compactMap { $0 }
                    : descriptor.stopIDs
                guard !path.isEmpty else { break }

                descriptors.append(
                    PathDescriptor(stopIDs: path, isMain: false, anchors: descriptor.anchors)
                )
                assign(path, to: &assigned, order: &assignedOrder)
            }
        }

        return descriptors
    }

    private func primaryPath(in component: Set<String>) -> [String] {
        guard component.count > 1 else { return ordered(component) }

        if let completeReference = referenceSequences.first(where: { sequence in
            sequence.count == component.count
                && Set(sequence) == component
                && Set(sequence).count == sequence.count
                && isPhysicalPath(sequence)
        }) {
            return orientByReference(completeReference)
        }

        let endpoints = ordered(
            Set(component.filter { neighbors(of: $0, in: component).count <= 1 })
        )
        let candidates = endpoints.count >= 2 ? endpoints : ordered(component)
        return longestShortestPath(between: candidates, allowed: component)
    }

    private func attachedPath(
        in component: Set<String>,
        assigned: Set<String>,
        assignedOrder: [String: Int]
    ) -> PathDescriptor {
        let allAnchors = Set(component.flatMap { stopID in
            adjacency[stopID, default: []].filter { assigned.contains($0) }
        })
        let anchors = allAnchors.sorted {
            let left = (assignedOrder[$0] ?? Int.max, rank(of: $0), $0)
            let right = (assignedOrder[$1] ?? Int.max, rank(of: $1), $1)
            return left < right
        }

        if anchors.count >= 2 {
            var bestPath: [String] = []
            for firstIndex in anchors.indices {
                for secondIndex in anchors.indices where secondIndex > firstIndex {
                    let first = anchors[firstIndex]
                    let second = anchors[secondIndex]
                    let allowed = component.union([first, second])
                    guard let candidate = shortestPath(
                        from: first,
                        to: second,
                        allowed: allowed,
                        forbiddenDirectAnchors: [first, second]
                    ) else { continue }
                    if prefers(candidate, over: bestPath) { bestPath = candidate }
                }
            }

            if !bestPath.isEmpty {
                let selectedAnchors = [bestPath.first, bestPath.last].compactMap { $0 }
                return PathDescriptor(
                    stopIDs: bestPath.filter { component.contains($0) },
                    isMain: false,
                    anchors: selectedAnchors
                )
            }
        }

        if let anchor = anchors.first {
            let endpoints = ordered(
                Set(component.filter { neighbors(of: $0, in: component).count <= 1 })
            )
            let candidates = endpoints.isEmpty ? ordered(component) : endpoints
            var bestPath: [String] = []
            for endpoint in candidates {
                guard let candidate = shortestPath(
                    from: anchor,
                    to: endpoint,
                    allowed: component.union([anchor])
                ) else { continue }
                if prefers(candidate, over: bestPath) { bestPath = candidate }
            }
            return PathDescriptor(
                stopIDs: bestPath.filter { component.contains($0) },
                isMain: false,
                anchors: [anchor]
            )
        }

        return PathDescriptor(
            stopIDs: primaryPath(in: component),
            isMain: false,
            anchors: []
        )
    }

    private func longestShortestPath(
        between candidates: [String],
        allowed: Set<String>
    ) -> [String] {
        var bestPath: [String] = []
        for firstIndex in candidates.indices {
            for secondIndex in candidates.indices where secondIndex > firstIndex {
                guard let candidate = shortestPath(
                    from: candidates[firstIndex],
                    to: candidates[secondIndex],
                    allowed: allowed
                ) else { continue }
                let oriented = orientByReference(candidate)
                if prefers(oriented, over: bestPath) { bestPath = oriented }
            }
        }
        return bestPath.isEmpty ? Array(ordered(allowed).prefix(1)) : bestPath
    }

    private func shortestPath(
        from start: String,
        to end: String,
        allowed: Set<String>,
        forbiddenDirectAnchors: Set<String> = []
    ) -> [String]? {
        guard allowed.contains(start), allowed.contains(end) else { return nil }
        var queue = [start]
        var queueIndex = 0
        var parent: [String: String] = [:]
        var visited: Set<String> = [start]

        while queueIndex < queue.count {
            let current = queue[queueIndex]
            queueIndex += 1
            if current == end { break }

            for neighbor in ordered(adjacency[current, default: []].intersection(allowed)) {
                if forbiddenDirectAnchors.contains(current),
                   forbiddenDirectAnchors.contains(neighbor) {
                    continue
                }
                guard visited.insert(neighbor).inserted else { continue }
                parent[neighbor] = current
                queue.append(neighbor)
            }
        }

        guard visited.contains(end) else { return nil }
        var path = [end]
        var current = end
        while current != start {
            guard let previous = parent[current] else { return nil }
            path.append(previous)
            current = previous
        }
        return path.reversed()
    }

    // MARK: - Presentation rows

    private func rows(for stopIDs: [String]) -> [LinePlan.StopRow] {
        stopIDs.enumerated().compactMap { index, stopID in
            guard let stop = stopsByID[stopID] else { return nil }
            let candidates = rowCandidates[stopID, default: []]
            let condition = candidates.compactMap(\.condition)
                .max { $0.severityRank < $1.severityRank }
            let isCutEdge = candidates.contains {
                $0.condition == condition && $0.isCutEdge
            }

            return LinePlan.StopRow(
                stop: stop,
                isEnd: adjacency[stopID, default: []].count <= 1,
                condition: condition,
                isCutEdge: condition != nil && isCutEdge,
                railAbove: index == 0
                    ? .none
                    : rail(from: stopIDs[index - 1], to: stopID),
                railBelow: index == stopIDs.count - 1
                    ? .none
                    : rail(from: stopID, to: stopIDs[index + 1])
            )
        }
    }

    private func role(for descriptor: PathDescriptor) -> LinePlan.Diagram.Section.Role {
        if descriptor.isMain { return .main }

        if descriptor.anchors.count >= 2,
           let first = stopsByID[descriptor.anchors[0]]?.name,
           let second = stopsByID[descriptor.anchors[1]]?.name {
            return .loop(from: first, to: second)
        }

        let name = descriptor.stopIDs.last.flatMap { stopsByID[$0]?.name } ?? ""
        let junction = descriptor.anchors.first.flatMap { stopsByID[$0]?.name }
        return .branch(name: name, junction: junction)
    }

    // MARK: - Determinism helpers

    private func connectedComponents(in nodes: Set<String>) -> [Set<String>] {
        var remaining = nodes
        var components: [Set<String>] = []

        while let start = ordered(remaining).first {
            var component: Set<String> = []
            var queue = [start]
            remaining.remove(start)

            while let current = queue.popLast() {
                component.insert(current)
                for neighbor in ordered(adjacency[current, default: []].intersection(remaining)) {
                    remaining.remove(neighbor)
                    queue.append(neighbor)
                }
            }
            components.append(component)
        }

        return components.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return rank(of: ordered($0).first ?? "") < rank(of: ordered($1).first ?? "")
        }
    }

    private func componentSortKey(
        _ component: Set<String>,
        assignedOrder: [String: Int]
    ) -> (Int, Int, String) {
        let anchors = component.flatMap { stopID in
            adjacency[stopID, default: []].compactMap { assignedOrder[$0] }
        }
        let first = ordered(component).first ?? ""
        return (anchors.min() ?? Int.max, rank(of: first), first)
    }

    private func assign(
        _ stopIDs: [String],
        to assigned: inout Set<String>,
        order: inout [String: Int]
    ) {
        for stopID in stopIDs where assigned.insert(stopID).inserted {
            order[stopID] = order.count
        }
    }

    private func neighbors(of stopID: String, in nodes: Set<String>) -> Set<String> {
        adjacency[stopID, default: []].intersection(nodes)
    }

    private func ordered(_ stopIDs: Set<String>) -> [String] {
        stopIDs.sorted {
            let left = (rank(of: $0), $0)
            let right = (rank(of: $1), $1)
            return left < right
        }
    }

    private func rank(of stopID: String) -> Int {
        referenceRank[stopID] ?? Int.max
    }

    private func orientByReference(_ path: [String]) -> [String] {
        guard let first = path.first, let last = path.last else { return path }
        let firstKey = (rank(of: first), first)
        let lastKey = (rank(of: last), last)
        return firstKey <= lastKey ? path : path.reversed()
    }

    private func prefers(_ candidate: [String], over current: [String]) -> Bool {
        guard candidate.count == current.count else { return candidate.count > current.count }
        for (left, right) in zip(candidate, current) {
            let leftKey = (rank(of: left), left)
            let rightKey = (rank(of: right), right)
            if leftKey != rightKey { return leftKey < rightKey }
        }
        return false
    }

    private func isPhysicalPath(_ stopIDs: [String]) -> Bool {
        zip(stopIDs, stopIDs.dropFirst()).allSatisfy {
            adjacency[$0.0, default: []].contains($0.1)
        }
    }

    private func rail(from firstID: String, to secondID: String) -> LinePlan.RailStyle {
        railByEdge[PhysicalEdge(firstID, secondID)] ?? .line
    }

    private func railSeverity(_ rail: LinePlan.RailStyle) -> Int {
        switch rail {
        case .none: -1
        case .line: 0
        case .cut(let condition): condition.severityRank + 1
        }
    }
}
