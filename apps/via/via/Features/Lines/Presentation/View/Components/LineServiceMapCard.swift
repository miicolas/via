import SwiftUI

struct LineServiceMapCard: View {
    let directions: [LineDirection]
    @Binding var selectedDirectionID: String
    let rows: [LineSchemaLayout.Row]
    let lineColor: Color
    let activeDisruptions: [LineDisruption]
    let onToggleRun: (String) -> Void

    private var selectedDirection: LineDirection? {
        directions.first { $0.id == selectedDirectionID } ?? directions.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Plan de la ligne")
                .font(.title3.weight(.bold))

            directionControl

            if !activeDisruptions.isEmpty {
                activeSummary
            }

            LineSchemaLegend()

            if let direction = selectedDirection {
                LineSchemaView(
                    rows: rows,
                    lineColor: lineColor,
                    directionLabel: direction.label,
                    onToggleRun: onToggleRun
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var directionControl: some View {
        if directions.count > 1, let selectedDirection {
            Picker(
                selection: $selectedDirectionID,
                label: Text("Vers \(selectedDirection.label)")
            ) {
                ForEach(directions) { direction in
                    Text("Vers \(direction.label)")
                        .tag(direction.id)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .accessibilityLabel("Direction")
        } else if let selectedDirection {
            Text("Vers \(selectedDirection.label)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }

    private var worstActiveCondition: LineCondition {
        activeDisruptions
            .map(\.condition)
            .max { $0.severityRank < $1.severityRank } ?? .attention
    }

    private var activeSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                "\(activeDisruptions.count) \(activeDisruptions.count == 1 ? "travail" : "travaux") en cours",
                systemImage: worstActiveCondition.systemImage
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(worstActiveCondition.tint)

            let sections = activeDisruptions.flatMap(\.impactedSections)
            ForEach(Array(sections.prefix(2).enumerated()), id: \.offset) { _, section in
                Text(impactText(for: section))
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if sections.count > 2 {
                Text("+ \(sections.count - 2) autres tronçons")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(worstActiveCondition.tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func impactText(for section: LineImpactedSection) -> String {
        guard !section.fromName.isEmpty,
              !section.toName.isEmpty,
              section.fromName != section.toName else {
            return "Zone concernée non précisée"
        }
        return "\(section.fromName) → \(section.toName)"
    }
}

#Preview("Service normal") {
    let detail = PreviewLineStatusRepository.metro1Detail
    let direction = detail.schemaDirections[0]

    LineServiceMapCard(
        directions: [direction],
        selectedDirectionID: .constant(direction.id),
        rows: LineSchemaLayout.rows(
            for: direction,
            disruptions: [],
            expandedRunIDs: []
        ),
        lineColor: Color(transitHex: detail.route.colorHex, fallback: .secondary),
        activeDisruptions: [],
        onToggleRun: { _ in }
    )
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
