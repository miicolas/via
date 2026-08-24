import SwiftUI

/// The journey rendered as a passenger information board: each leg owns one
/// continuous rail and transit legs introduce themselves with a train diagram.
struct JourneyTimelineView: View {
    enum Mode: Equatable {
        case plan
        case live(JourneyProgress)

        var progress: JourneyProgress? {
            switch self {
            case .plan: nil
            case .live(let progress): progress
            }
        }
    }

    let journey: Journey
    var mode: Mode = .plan
    @Binding var expandedSectionIDs: Set<String>
    var highlightedSectionID: String?
    var onSelectSection: ((String) -> Void)?
    var departureChoices: JourneyDepartureChoicesModel?
    var revisableSectionIDs: Set<String> = []
    var onSelectDeparture: ((JourneyDepartureChoice, String) -> Void)?
    var onRetryDepartures: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func currentNodeID(in journey: Journey, progress: JourneyProgress?) -> String? {
        let nodes = JourneyTimeline.nodes(for: journey)
        return JourneyTimeline.cursor(in: nodes, progress: progress)?.nodeID
            ?? nodes.first { JourneyTimeline.state(of: $0, progress: progress) == .current }?.id
    }

    var body: some View {
        let allNodes = JourneyTimeline.nodes(for: journey)
        let nodes = displayNodes(from: allNodes)
        let cursor = JourneyTimeline.cursor(in: allNodes, progress: mode.progress)
        let groups = nodeGroups(from: nodes)

        VStack(spacing: 0) {
            ForEach(groups) { group in
                JourneyTimelineSectionView(
                    nodes: group.nodes,
                    progress: mode.progress,
                    cursor: cursor,
                    isCursorLive: mode.progress?.isLocationDerived == true,
                    isHighlighted: group.isSelectable
                        && highlightedSectionID == group.sectionID,
                    isExpanded: binding(for: group.sectionID),
                    departureChoicesGroup: departureChoices?.groupsBySectionID[group.sectionID],
                    isDepartureChoicesLoading: departureChoices?.isRefreshing == true,
                    isSelectingDeparture: departureChoices?.selectingSectionID == group.sectionID,
                    departureChoicesError: departureChoices?.errorMessage(for: group.sectionID),
                    canSelectDepartures: revisableSectionIDs.contains(group.sectionID),
                    onSelectDeparture: onSelectDeparture.map { select in
                        { choice in select(choice, group.sectionID) }
                    },
                    onRetryDepartures: onRetryDepartures,
                    onSelect: group.isSelectable
                        ? onSelectSection.map { select in { select(group.sectionID) } }
                        : nil
                )
                .simultaneousGesture(swipeGesture(for: group))
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: mode)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: highlightedSectionID)
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: expandedSectionIDs)
        .sensoryFeedback(.selection, trigger: expandedSectionIDs)
    }

    /// Boarding at the origin and alighting at the destination already name
    /// those places. Suppressing their duplicate endpoint rows keeps the board
    /// as direct as the supplied RER displays without changing the domain model.
    private func displayNodes(from nodes: [JourneyTimelineNode]) -> [JourneyTimelineNode] {
        nodes.enumerated().compactMap { index, node in
            guard node.isTravellerInstruction else { return nil }

            if case .origin = node.kind,
               node.railBelow == .none,
               nodes.indices.contains(index + 1),
               case .board = nodes[index + 1].kind {
                return nil
            }

            if case .destination = node.kind,
               node.railAbove == .none,
               index > 0,
               case .alight = nodes[index - 1].kind {
                return nil
            }

            return node
        }
    }

    private func nodeGroups(from nodes: [JourneyTimelineNode]) -> [JourneyTimelineNodeGroup] {
        var groups: [JourneyTimelineNodeGroup] = []

        for node in nodes {
            let isEndpoint = switch node.kind {
            case .origin, .destination: true
            default: false
            }

            if !isEndpoint,
               let last = groups.indices.last,
               groups[last].isSelectable,
               groups[last].sectionID == node.sectionID {
                groups[last].nodes.append(node)
            } else {
                groups.append(
                    JourneyTimelineNodeGroup(
                        id: isEndpoint ? "endpoint:\(node.id)" : "section:\(node.sectionID)",
                        sectionID: node.sectionID,
                        nodes: [node],
                        isSelectable: !isEndpoint
                    )
                )
            }
        }

        return groups
    }

    private func binding(for sectionID: String) -> Binding<Bool> {
        Binding(
            get: { expandedSectionIDs.contains(sectionID) },
            set: { setExpanded($0, for: sectionID) }
        )
    }

    private func swipeGesture(for group: JourneyTimelineNodeGroup) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard group.hasExpandableStops else { return }
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 44,
                      abs(horizontal) > abs(vertical) * 1.35 else { return }
                setExpanded(horizontal > 0, for: group.sectionID)
            }
    }

    private func setExpanded(_ isExpanded: Bool, for sectionID: String) {
        if isExpanded {
            expandedSectionIDs.insert(sectionID)
        } else {
            expandedSectionIDs.remove(sectionID)
        }
    }
}

private struct JourneyTimelineNodeGroup: Identifiable {
    var id: String
    var sectionID: String
    var nodes: [JourneyTimelineNode]
    var isSelectable: Bool

    var hasExpandableStops: Bool {
        nodes.contains { node in
            if case .ride(let stops) = node.kind { return stops.count > 1 }
            return false
        }
    }
}
