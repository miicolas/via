import SwiftUI

/// One station of the plan, drawn on the journey timeline's own rail: the same
/// wide coloured band, the same white station hole punched through it. A line
/// read from the Lignes tab and a leg read from a trip are then not two
/// drawings that resemble each other — they are the one view.
///
/// What is wrong at a station is said inside its hole: tinted while the station
/// sits in a disruption, struck through when no train calls there any more. The
/// pictogram stays for the two edges of a cut, where it says the stretch starts
/// or stops rather than repeating what the hole already shows.
struct LinePlanStopRow: View {
    let row: LinePlan.StopRow
    let lineColorHex: String?
    /// A branch's stations sit one step in from the trunk's, so the fork reads
    /// as a fork and not as the line carrying on.
    var isIndented: Bool = false

    /// The bead sits a fixed distance down the rail, so the row it belongs to
    /// has to grow with it — otherwise the hole drifts off the name at the
    /// accessibility sizes.
    @ScaledMetric(relativeTo: .headline) private var rowHeight: CGFloat = 44

    private let textPadding: CGFloat = 11

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            JourneyTimelineRail(
                above: row.railAbove.timelineStyle(colorHex: lineColorHex),
                below: row.railBelow.timelineStyle(colorHex: lineColorHex),
                bead: row.isEnd ? .major : .minor,
                mark: row.mark,
                state: .upcoming
            )
            .frame(maxHeight: .infinity)

            Text(row.stop.name)
                .font(row.isEnd ? .subheadline.weight(.bold) : .subheadline)
                .foregroundStyle(row.condition != nil || row.isEnd ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 10)
                .padding(.vertical, textPadding)

            // No interchange glyph here on purpose: on a Paris metro line four
            // stations in five are one, so the mark carried no information and
            // every row wore it. Correspondances belong to the station screen,
            // where they are named.
            if row.isCutEdge, let condition = row.condition {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(condition.tint)
                    .padding(.trailing, 4)
                    .padding(.vertical, textPadding)
            }
        }
        .padding(.leading, isIndented ? 18 : 0)
        .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
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

#Preview("Interruption au milieu du tronc") {
    let detail = PreviewLineStatusRepository.metro1Detail
    let strips = LinePlan.strips(
        for: detail.planDirection!,
        disruptions: detail.disruptions
    )

    ScrollView {
        VStack(spacing: 0) {
            ForEach(Array(strips.flatMap(\.stops).enumerated()), id: \.offset) { _, row in
                LinePlanStopRow(row: row, lineColorHex: detail.route.colorHex)
            }
        }
        .padding()
    }
}
