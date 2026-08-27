import SwiftUI

/// A complete line schematic, drawn as one graph: stations appear once and
/// parallel branches remain visibly connected to their shared stems.
struct LinePlanView: View {
    let diagram: LinePlan.Diagram
    let lineColorHex: String

    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 48

    private let laneOrigin: CGFloat = 18
    private let laneSpacing: CGFloat = 22
    private let bandWidth: CGFloat = 16
    private let stopSize: CGFloat = 12
    private let terminusSize: CGFloat = 18

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
                drawSectionRails(in: &context)
                drawConnections(in: &context)
            }
            .accessibilityHidden(true)

            ForEach(positionedStops) { node in
                stationRow(node)
                    .offset(y: CGFloat(node.rowIndex) * rowHeight)

                stationMark(node)
                    .position(x: x(for: node.lane), y: y(for: node))
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: diagramHeight, maxHeight: diagramHeight)
    }

    private func stationRow(_ node: PositionedStop) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Color.clear
                .frame(width: labelInset)
                .accessibilityHidden(true)

            Text(node.row.stop.name)
                .font(node.row.isEnd ? .subheadline.weight(.bold) : .subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if node.row.isCutEdge, let condition = node.row.condition {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(condition.tint)
            }
        }
        .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: node.row))
    }

    @ViewBuilder
    private func stationMark(_ node: PositionedStop) -> some View {
        let size = node.row.isEnd ? terminusSize : stopSize

        Circle()
            .fill(.white)
            .overlay {
                switch node.row.mark {
                case .open:
                    EmptyView()
                case .warned(let condition):
                    Circle()
                        .fill(condition.tint)
                        .padding(3)
                case .closed(let condition):
                    Image(systemName: "xmark")
                        .font(.system(size: size * 0.58, weight: .black))
                        .foregroundStyle(condition.tint)
                }
            }
            .frame(width: size, height: size)
    }

    private func drawSectionRails(in context: inout GraphicsContext) {
        for section in diagram.sections {
            let nodes = positionedStops.filter { $0.sectionID == section.id }
            for index in nodes.indices.dropLast() {
                var path = Path()
                path.move(to: point(for: nodes[index]))
                path.addLine(to: point(for: nodes[index + 1]))
                stroke(path, as: nodes[index].row.railBelow, in: &context)
            }
        }
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
            var path = Path()
            path.move(to: start)
            if start.x == end.x {
                path.addLine(to: end)
            } else {
                let middleY = (start.y + end.y) / 2
                path.addCurve(
                    to: end,
                    control1: CGPoint(x: start.x, y: middleY),
                    control2: CGPoint(x: end.x, y: middleY)
                )
            }
            stroke(path, as: edge.rail, in: &context)
        }
    }

    private func stroke(_ path: Path, as rail: LinePlan.RailStyle, in context: inout GraphicsContext) {
        let appearance: (color: Color, dash: [CGFloat]) = switch rail {
        case .none:
            (.clear, [])
        case .line:
            (lineColor, [])
        case .cut(let condition):
            (condition.tint, [13, 8])
        }
        context.stroke(
            path,
            with: .color(appearance.color),
            style: StrokeStyle(
                lineWidth: bandWidth,
                lineCap: .round,
                lineJoin: .round,
                dash: appearance.dash
            )
        )
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

    private func x(for lane: Int) -> CGFloat {
        laneOrigin + CGFloat(lane) * laneSpacing
    }

    private func y(for node: PositionedStop) -> CGFloat {
        CGFloat(node.rowIndex) * rowHeight + rowHeight / 2
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
