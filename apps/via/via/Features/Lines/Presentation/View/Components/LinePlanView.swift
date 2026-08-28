import SwiftUI

/// A complete line schematic, drawn as one graph: stations appear once and
/// parallel branches remain visibly connected to their shared stems.
struct LinePlanView: View {
    let diagram: LinePlan.Diagram
    let lineColorHex: String

    /// The stop list in a journey has a 58-point row and places its station
    /// hole 22 points from the top. Keeping those two anchors here makes the
    /// names and holes land on the exact same baseline in both screens.
    @ScaledMetric(relativeTo: .title3) private var rowHeight: CGFloat = 58
    @ScaledMetric(relativeTo: .headline) private var beadCenter: CGFloat = 22

    private let laneSpacing = JourneyTimelineRail.transitWidth + 6
    private let textPadding: CGFloat = 10

    private var laneOrigin: CGFloat { JourneyTimelineRail.width / 2 }
    private var bandWidth: CGFloat { JourneyTimelineRail.transitWidth }

    private var lineColor: Color {
        Color(transitHex: lineColorHex, fallback: .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Schéma complet de la ligne")
                .font(.title3.weight(.bold))

            if positionedStops.isEmpty {
                EmptyStateView(
                    .unavailable(
                        title: "Plan indisponible",
                        message: "Le détail des gares de cette ligne n’est pas encore disponible."
                    )
                )
            } else {
                schematic
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .detailCard()
        .accessibilityElement(children: .contain)
    }

    private var schematic: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawConnections(in: &context)
            }
            .accessibilityHidden(true)

            ForEach(positionedStops) { node in
                stationRail(node)
                    .frame(height: rowHeight)
                    .position(
                        x: x(for: node.lane),
                        y: rowTop(for: node) + rowHeight / 2
                    )
                    .accessibilityHidden(true)
            }

            ForEach(positionedStops) { node in
                stationRow(node)
                    .offset(y: rowTop(for: node))
            }
        }
        .frame(maxWidth: .infinity, minHeight: diagramHeight, maxHeight: diagramHeight)
    }

    private func stationRail(_ node: PositionedStop) -> some View {
        JourneyTimelineRail(
            above: node.row.railAbove.timelineStyle(colorHex: lineColorHex),
            below: node.row.railBelow.timelineStyle(colorHex: lineColorHex),
            bead: node.row.isEnd ? .terminus : .minor,
            mark: node.row.mark,
            state: .upcoming
        )
    }

    private func stationRow(_ node: PositionedStop) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Color.clear
                .frame(width: labelInset)
                .accessibilityHidden(true)

            Text(node.row.stop.name)
                .font(.title3.weight(node.row.isEnd ? .bold : .semibold))
                .foregroundStyle(node.row.condition?.tint ?? lineColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 10)
                .padding(.vertical, textPadding)

            if node.row.isCutEdge, let condition = node.row.condition {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(condition.tint)
                    .padding(.trailing, 4)
                    .padding(.vertical, textPadding)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: rowHeight,
            maxHeight: rowHeight,
            alignment: .topLeading
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: node.row))
    }

    private func drawConnections(in context: inout GraphicsContext) {
        let firstBySection = Dictionary(
            uniqueKeysWithValues: diagram.sections.compactMap { section in
                positionedStops.first(where: { $0.sectionID == section.id }).map { (section.id, $0) }
            }
        )
        let lastBySection = Dictionary(
            uniqueKeysWithValues: diagram.sections.compactMap { section in
                positionedStops.last(where: { $0.sectionID == section.id }).map { (section.id, $0) }
            }
        )

        for edge in diagram.edges {
            guard let from = lastBySection[edge.fromSectionID],
                  let to = firstBySection[edge.toSectionID] else { continue }

            let start = point(for: from)
            let end = point(for: to)
            let path = connectionPath(
                from: start,
                to: end,
                leavesFork: outgoingEdgeCount[edge.fromSectionID, default: 0] > 1,
                joinsMerge: incomingEdgeCount[edge.toSectionID, default: 0] > 1
            )
            stroke(path, as: edge.rail, in: &context)
        }
    }

    /// Platform diagrams shift lanes with a short diagonal, then remain
    /// perfectly straight. At a fork the diagonal happens immediately; at a
    /// merge it happens just before the shared stem. Rounded joins soften only
    /// those corners instead of turning the whole connection into an S-curve.
    private func connectionPath(
        from start: CGPoint,
        to end: CGPoint,
        leavesFork: Bool,
        joinsMerge: Bool
    ) -> Path {
        var path = Path()
        path.move(to: start)

        let verticalDistance = end.y - start.y
        let horizontalDistance = abs(end.x - start.x)
        guard horizontalDistance > 0, verticalDistance > 0 else {
            path.addLine(to: end)
            return path
        }

        let diagonalHeight = min(horizontalDistance, verticalDistance)
        if leavesFork && !joinsMerge {
            path.addLine(to: CGPoint(x: end.x, y: start.y + diagonalHeight))
        } else if joinsMerge && !leavesFork {
            path.addLine(to: CGPoint(x: start.x, y: end.y - diagonalHeight))
        } else {
            let straightHeight = max(0, (verticalDistance - diagonalHeight) / 2)
            path.addLine(to: CGPoint(x: start.x, y: start.y + straightHeight))
            path.addLine(to: CGPoint(x: end.x, y: end.y - straightHeight))
        }
        path.addLine(to: end)
        return path
    }

    private func stroke(
        _ path: Path,
        as rail: LinePlan.RailStyle,
        in context: inout GraphicsContext
    ) {
        let appearance: (color: Color, dash: [CGFloat]) = switch rail {
        case .none:
            (.clear, [])
        case .line:
            (lineColor, [])
        case .cut(let condition):
            (condition.tint, JourneyTimelineRail.interruptedDash)
        }
        context.stroke(
            path,
            with: .color(appearance.color),
            style: StrokeStyle(
                lineWidth: bandWidth,
                lineCap: .butt,
                lineJoin: .round,
                dash: appearance.dash
            )
        )
    }

    private var incomingEdgeCount: [String: Int] {
        Dictionary(grouping: diagram.edges, by: \.toSectionID).mapValues(\.count)
    }

    private var outgoingEdgeCount: [String: Int] {
        Dictionary(grouping: diagram.edges, by: \.fromSectionID).mapValues(\.count)
    }

    private var positionedStops: [PositionedStop] {
        var rowIndex = 0
        return diagram.sections.flatMap { section in
            section.stops.map { row in
                defer { rowIndex += 1 }
                return PositionedStop(
                    sectionID: section.id,
                    lane: section.lane,
                    rowIndex: rowIndex,
                    row: row
                )
            }
        }
    }

    private var maxLane: Int {
        diagram.sections.map(\.lane).max() ?? 0
    }

    private var labelInset: CGFloat {
        x(for: maxLane) + bandWidth / 2 + 14
    }

    private var diagramHeight: CGFloat {
        CGFloat(positionedStops.count) * rowHeight
    }

    private func rowTop(for node: PositionedStop) -> CGFloat {
        CGFloat(node.rowIndex) * rowHeight
    }

    private func x(for lane: Int) -> CGFloat {
        laneOrigin + CGFloat(lane) * laneSpacing
    }

    private func y(for node: PositionedStop) -> CGFloat {
        rowTop(for: node) + beadCenter
    }

    private func point(for node: PositionedStop) -> CGPoint {
        CGPoint(x: x(for: node.lane), y: y(for: node))
    }

    private func accessibilityLabel(for row: LinePlan.StopRow) -> String {
        var labels = [row.stop.name]
        switch row.mark {
        case .open:
            break
        case .warned(let condition):
            labels.append(condition.title)
        case .closed(let condition):
            labels.append("\(condition.title), aucun train ne dessert cette gare")
        }
        return labels.joined(separator: ", ")
    }
}

private struct PositionedStop: Identifiable {
    let sectionID: String
    let lane: Int
    let rowIndex: Int
    let row: LinePlan.StopRow

    var id: String { row.stop.id }
}

#Preview("RER A — schéma complet") {
    let detail = PreviewLineStatusRepository.rerADetail
    let diagram = LinePlan.diagram(
        for: detail.planDirection!,
        disruptions: detail.disruptions
    )

    ScrollView {
        LinePlanView(
            diagram: diagram,
            lineColorHex: detail.route.colorHex
        )
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
