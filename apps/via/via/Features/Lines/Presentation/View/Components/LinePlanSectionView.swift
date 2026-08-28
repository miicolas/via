import SwiftUI

/// One contiguous path of a complete line plan. The main path, every branch,
/// and every direction-specific loop starts its own rail so visual reading
/// order can never invent an inter-station connection.
struct LinePlanSectionView: View {
    let section: LinePlan.Diagram.Section
    let lineColorHex: String

    private var lineColor: Color {
        Color(transitHex: lineColorHex, fallback: .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            heading

            VStack(spacing: 0) {
                ForEach(section.stops, id: \.stop.id) { row in
                    stationRow(row)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: headingSymbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(lineColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(headingTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let headingSubtitle {
                    Text(headingSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func stationRow(_ row: LinePlan.StopRow) -> some View {
        HStack(alignment: .top, spacing: 0) {
            JourneyTimelineRail(
                above: row.railAbove.timelineStyle(colorHex: lineColorHex),
                below: row.railBelow.timelineStyle(colorHex: lineColorHex),
                bead: row.isEnd ? .terminus : .minor,
                mark: row.mark,
                state: .upcoming
            )
            .frame(maxHeight: .infinity)

            Text(row.stop.name)
                .font(.title3.weight(row.isEnd ? .bold : .semibold))
                .foregroundStyle(row.condition?.tint ?? lineColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 10)
                .padding(.vertical, 10)

            if row.isCutEdge, let condition = row.condition {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(condition.tint)
                    .padding(.trailing, 4)
                    .padding(.vertical, 10)
            }
        }
        .frame(minHeight: 58, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: row))
    }

    private var headingSymbol: String {
        switch section.role {
        case .main: "point.topleft.down.to.point.bottomright.curvepath"
        case .branch: "arrow.triangle.branch"
        case .loop: "arrow.clockwise"
        }
    }

    private var headingTitle: String {
        switch section.role {
        case .main:
            "Parcours continu"
        case .branch(let name, _):
            "Branche \(name)"
        case .loop:
            "Boucle"
        }
    }

    private var headingSubtitle: String? {
        switch section.role {
        case .main:
            nil
        case .branch(_, let junction):
            junction.map { "Depuis \($0)" }
        case .loop(let from, let to):
            "Entre \(from) et \(to)"
        }
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
