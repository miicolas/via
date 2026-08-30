import SwiftUI

/// A complete leg on the route board. Transit legs add their train guidance
/// before the station rail; walking and transfer legs remain rail-only.
struct JourneyTimelineSectionView: View {
    let nodes: [JourneyTimelineNode]
    let currentSectionIndex: Int?
    let liveStopProgress: JourneyStopProgress?
    @Binding var isExpanded: Bool
    var departureChoicesGroup: JourneyDepartureChoiceGroup?
    var isDepartureChoicesLoading = false
    var isSelectingDeparture = false
    var departureChoicesError: String?
    var canSelectDepartures = false
    var onSelectDeparture: ((JourneyDepartureChoice) -> Void)?
    var onRetryDepartures: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if let boardingInformation {
                JourneyBoardingPositionView(
                    route: boardingInformation.route,
                    position: boardingInformation.position,
                    isDimmed: boardingInformation.state == .done
                )
            }

            ForEach(nodes) { node in
                JourneyTimelineNodeRow(
                    node: node,
                    state: JourneyTimeline.state(
                        of: node,
                        currentSectionIndex: currentSectionIndex
                    ),
                    liveStopProgress: liveStopProgress,
                    isExpanded: $isExpanded,
                    departureChoicesGroup: departureChoicesGroup,
                    isDepartureChoicesLoading: isDepartureChoicesLoading,
                    isSelectingDeparture: isSelectingDeparture,
                    departureChoicesError: departureChoicesError,
                    canSelectDepartures: canSelectDepartures,
                    onSelectDeparture: onSelectDeparture,
                    onRetryDepartures: onRetryDepartures
                )
                .id(node.id)
            }
        }
    }

    private var boardingInformation: (
        route: JourneyRoute,
        position: JourneyBoardingPosition,
        state: JourneyTimelineNodeState
    )? {
        for node in nodes {
            guard case .board(_, let route, _, _, let position) = node.kind,
                  let route,
                  let position else { continue }
            return (
                route,
                position,
                JourneyTimeline.state(
                    of: node,
                    currentSectionIndex: currentSectionIndex
                )
            )
        }
        return nil
    }
}
