import SwiftUI

/// The whole journey as one continuous rail.
///
/// `mode` is the only difference between the pre-trip detail and live guidance:
/// in `.plan` every node reads as upcoming and no cursor is drawn; in `.live`
/// the travelled part dims and a cursor rides the rail. Keeping one view for
/// both is what makes the two screens read as the same object.
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
    /// `nil` leaves the rows non-interactive, which is what guidance wants.
    var onSelectSection: ((String) -> Void)?

    /// Identifier the guidance screen scrolls to when the traveller advances.
    static func currentNodeID(in journey: Journey, progress: JourneyProgress?) -> String? {
        let nodes = JourneyTimeline.nodes(for: journey)
        return JourneyTimeline.cursor(in: nodes, progress: progress)?.nodeID
            ?? nodes.first { JourneyTimeline.state(of: $0, progress: progress) == .current }?.id
    }

    var body: some View {
        let nodes = JourneyTimeline.nodes(for: journey)
        let cursor = JourneyTimeline.cursor(in: nodes, progress: mode.progress)
        let groups = nodeGroups(from: nodes)
        // Rank in the whole rail, not in the group: the cascade has to run down
        // the journey once, not restart at every leg.
        let ranks = Dictionary(
            uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, $0.offset) }
        )

        VStack(spacing: 0) {
            ForEach(groups) { group in
                let isSelected = group.isSelectable && highlightedSectionID == group.sectionID

                VStack(spacing: 0) {
                    ForEach(group.nodes) { node in
                        JourneyTimelineNodeRow(
                            node: node,
                            state: JourneyTimeline.state(of: node, progress: mode.progress),
                            cursorFraction: cursor?.nodeID == node.id ? cursor?.fraction : nil,
                            isCursorLive: mode.progress?.isLocationDerived == true,
                            isHighlighted: isSelected,
                            isExpanded: binding(for: node.sectionID),
                            onSelect: onSelectSection.map { select in { select(node.sectionID) } }
                        )
                        .id(node.id)
                        .staggeredAppearance(rank: ranks[node.id] ?? 0)
                    }
                }
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.accentColor.opacity(0.045))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.accentColor.opacity(0.24), lineWidth: 1.5)
                            }
                            .padding(.leading, JourneyTimelineRail.width - 6)
                    }
                }
            }
        }
        // One animation for the whole rail: when progress moves, the colours,
        // the dimming and the position bubble travel together instead of each
        // row snapping to its new state on its own.
        .animation(.smooth(duration: 0.45), value: mode)
        .animation(.smooth(duration: 0.25), value: highlightedSectionID)
    }

    /// Endpoint rows describe the whole journey, while the rows between them
    /// describe one selectable leg. Keeping a leg in one group gives selection
    /// a single continuous surface instead of disconnected pills at each stop.
    private func nodeGroups(from nodes: [JourneyTimelineNode]) -> [NodeGroup] {
        var groups: [NodeGroup] = []

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
                    NodeGroup(
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
            set: { isExpanded in
                if isExpanded {
                    expandedSectionIDs.insert(sectionID)
                } else {
                    expandedSectionIDs.remove(sectionID)
                }
            }
        )
    }
}

private struct NodeGroup: Identifiable {
    let id: String
    let sectionID: String
    var nodes: [JourneyTimelineNode]
    let isSelectable: Bool
}

#Preview("Détail") {
    @Previewable @State var expanded: Set<String> = []

    ScrollView {
        JourneyTimelineView(
            journey: .mapPreviewMultipleTransfers,
            expandedSectionIDs: $expanded
        )
        .padding(.horizontal, 16)
    }
}

#Preview("En direct") {
    @Previewable @State var expanded: Set<String> = []
    let journey = Journey.mapPreviewMultipleTransfers
    let progress = JourneyProgressProjector.progress(
        schedule: ActiveJourneyRules.schedule(for: journey),
        sectionIndex: 1,
        at: journey.departureAt.addingTimeInterval(600),
        coordinate: nil,
        horizontalAccuracy: nil
    )

    return ScrollView {
        JourneyTimelineView(
            journey: journey,
            mode: .live(progress),
            expandedSectionIDs: $expanded
        )
        .padding(.horizontal, 16)
    }
}

#Preview("Grande taille de texte") {
    @Previewable @State var expanded: Set<String> = []

    ScrollView {
        JourneyTimelineView(
            journey: .mapPreviewMultipleTransfers,
            expandedSectionIDs: $expanded
        )
        .padding(.horizontal, 16)
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}
