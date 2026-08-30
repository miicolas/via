import SwiftUI

/// One contiguous physical path rendered with the exact station-row grammar
/// used by Journey: one wide rail, one bead, and one adjacent label.
struct LinePlanSectionView: View {
    let section: LinePlan.Diagram.Section
    let lineColorHex: String
    var showsHeading = true

    private var lineColor: Color {
        Color(transitHex: lineColorHex, fallback: .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: showsHeading ? 6 : 0) {
            if showsHeading {
                heading
            }

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

                if let headingSubtitle {
                    Text(headingSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
                bead: bead(for: row),
                mark: row.mark,
                state: .upcoming
            )
            .frame(maxHeight: .infinity)

            Text(row.stop.name)
                .font(.title3.weight(row.isEnd ? .bold : .semibold))
                .foregroundStyle(row.condition?.tint ?? lineColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 10)
                .padding(.vertical, 10)

            if row.isCutEdge, let condition = row.condition {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(condition.tint)
                    .padding(.trailing, 4)
                    .padding(.vertical, 10)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 58, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: row))
    }

    private func bead(for row: LinePlan.StopRow) -> JourneyTimelineBead {
        if row.isEnd { return .terminus }
        if row.stop.isInterchange { return .major }
        return .minor
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
            "Tronc commun"
        case .branch(let name, _):
            name
        case .loop:
            "Boucle"
        }
    }

    private var headingSubtitle: String? {
        switch section.role {
        case .main:
            guard let first = section.stops.first?.stop.name,
                  let last = section.stops.last?.stop.name,
                  first != last else { return nil }
            return "\(first) ↔ \(last)"
        case .branch(_, let junction):
            return junction.map { "Jonction à \($0)" }
        case .loop(let from, let to):
            return "Entre \(from) et \(to)"
        }
    }

    private func accessibilityLabel(for row: LinePlan.StopRow) -> String {
        var labels = [row.stop.name]
        if row.stop.isInterchange { labels.append("Correspondance") }
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
