import SwiftUI

/// A complete line plan split into independently readable physical paths.
/// Each path is contiguous; a branch heading names its real junction instead
/// of letting the end of the preceding branch masquerade as its previous stop.
struct LinePlanView: View {
    let diagram: LinePlan.Diagram
    let lineColorHex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Schéma complet de la ligne")
                .font(.title3.weight(.bold))

            if diagram.sections.allSatisfy(\.stops.isEmpty) {
                EmptyStateView(
                    .unavailable(
                        title: "Plan indisponible",
                        message: "Le détail des gares de cette ligne n’est pas encore disponible."
                    )
                )
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(diagram.sections) { section in
                        LinePlanSectionView(
                            section: section,
                            lineColorHex: lineColorHex
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .detailCard()
        .accessibilityElement(children: .contain)
    }
}

#Preview("RER A — schéma complet") {
    let detail = PreviewLineStatusRepository.rerADetail
    let diagram = LinePlan.diagram(
        for: detail.schemaDirections,
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
