import SwiftUI

/// The plan of the line: the trunk drawn open as a vertical rail, and each
/// branch folded into one row underneath — or above, when it feeds the trunk.
///
/// Nothing here is a direction. A plan read upwards is the other way round, so
/// the screen shows the stations once and spares the rider a picker before
/// they have seen anything.
struct LinePlanView: View {
    let strips: [LinePlan.Strip]
    let lineColor: Color
    let isOpen: (LinePlan.Strip) -> Bool
    let onToggle: (LinePlan.Strip) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Plan de la ligne")
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
                    ForEach(strips) { strip in
                        if case .branch(let name) = strip.role {
                            LineBranchRow(
                                name: name,
                                stopCount: strip.stops.count,
                                condition: strip.condition,
                                lineColor: lineColor,
                                isOpen: isOpen(strip),
                                action: { onToggle(strip) }
                            )
                        }

                        if isOpen(strip) {
                            ForEach(strip.stops, id: \.stop.id) { row in
                                LinePlanStopRow(
                                    row: row,
                                    lineColor: lineColor,
                                    isIndented: strip.role.isBranch
                                )
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .detailCard()
        .accessibilityElement(children: .contain)
    }
}

#Preview("RER A — tronc et branches") {
    @Previewable @State var opened: Set<String> = []
    let detail = PreviewLineStatusRepository.rerADetail
    let strips = LinePlan.strips(
        for: detail.planDirection!,
        disruptions: detail.disruptions
    )

    ScrollView {
        LinePlanView(
            strips: strips,
            lineColor: Color(transitHex: detail.route.colorHex, fallback: .secondary),
            isOpen: { $0.role == .trunk || $0.condition != nil || opened.contains($0.id) },
            onToggle: { strip in
                if !opened.insert(strip.id).inserted { opened.remove(strip.id) }
            }
        )
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
