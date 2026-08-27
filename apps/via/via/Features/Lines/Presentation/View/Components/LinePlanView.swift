import SwiftUI

/// The complete plan of the line: the trunk and every branch are visible at
/// once, joined by the same broad curves riders see on platform displays.
///
/// Nothing here is a direction. A plan read upwards is the other way round, so
/// the screen shows the stations once and spares the rider a picker before
/// they have seen anything.
struct LinePlanView: View {
    let strips: [LinePlan.Strip]
    /// The rail takes the hex rather than a resolved `Color`: it is the shared
    /// journey rail, and that is the vocabulary a leg's colour travels in.
    let lineColorHex: String

    private var lineColor: Color {
        Color(transitHex: lineColorHex, fallback: .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Schéma complet de la ligne")
                .font(.title3.weight(.bold))

            if strips.isEmpty {
                EmptyStateView(
                    .unavailable(
                        title: "Plan indisponible",
                        message: "Le détail des gares de cette ligne n’est pas encore disponible.",
                    ),
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(strips.enumerated()), id: \.element.id) { index, strip in
                        stripView(strip, at: index)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .detailCard()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func stripView(_ strip: LinePlan.Strip, at index: Int) -> some View {
        let trunkIndex = strips.firstIndex { $0.role == .trunk }
        let joinsTrunkBelow = trunkIndex.map { index < $0 } ?? false
        let leavesTrunkAbove = trunkIndex.map { index > $0 } ?? false

        if case .branch(let name) = strip.role, leavesTrunkAbove {
            LineBranchRow(
                name: name,
                condition: strip.condition,
                lineColor: lineColor,
                direction: .leavesTrunk
            )
        }

        ForEach(Array(strip.stops.enumerated()), id: \.element.stop.id) { stopIndex, row in
            LinePlanStopRow(
                row: row,
                lineColorHex: lineColorHex,
                isIndented: strip.role.isBranch,
                connectsAbove: connectsAbove(
                    strip: strip,
                    stripIndex: index,
                    stopIndex: stopIndex,
                    trunkIndex: trunkIndex
                ),
                connectsBelow: connectsBelow(
                    strip: strip,
                    stripIndex: index,
                    stopIndex: stopIndex,
                    trunkIndex: trunkIndex
                )
            )
        }

        if case .branch(let name) = strip.role, joinsTrunkBelow {
            LineBranchRow(
                name: name,
                condition: strip.condition,
                lineColor: lineColor,
                direction: .joinsTrunk
            )
        }
    }

    private func connectsAbove(
        strip: LinePlan.Strip,
        stripIndex: Int,
        stopIndex: Int,
        trunkIndex: Int?
    ) -> Bool {
        guard stopIndex == 0, let trunkIndex else { return false }
        return stripIndex > trunkIndex || (stripIndex == trunkIndex && trunkIndex > 0)
    }

    private func connectsBelow(
        strip: LinePlan.Strip,
        stripIndex: Int,
        stopIndex: Int,
        trunkIndex: Int?
    ) -> Bool {
        guard stopIndex == strip.stops.count - 1, let trunkIndex else { return false }
        return stripIndex < trunkIndex || (stripIndex == trunkIndex && trunkIndex < strips.count - 1)
    }
}

#Preview("RER A — tronc et branches") {
    let detail = PreviewLineStatusRepository.rerADetail
    let strips = LinePlan.diagramStrips(
        for: detail.planDirection!,
        disruptions: detail.disruptions
    )

    ScrollView {
        LinePlanView(
            strips: strips,
            lineColorHex: detail.route.colorHex
        )
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
