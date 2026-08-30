import SwiftUI

/// A line plan that stays readable as the network grows. The common trunk is
/// the stable Journey-style timeline; each additional physical path is one
/// disclosure row and expands into the same single-rail timeline.
struct LinePlanView: View {
    let diagram: LinePlan.Diagram
    let lineColorHex: String

    @State private var expandedSectionID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var lineColor: Color {
        Color(transitHex: lineColorHex, fallback: .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan de la ligne")
                    .font(.title3.weight(.bold))

                if !allStops.isEmpty {
                    Text(planSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if allStops.isEmpty {
                EmptyStateView(
                    .unavailable(
                        title: "Plan indisponible",
                        message: "Le détail des gares de cette ligne n’est pas encore disponible."
                    )
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if let mainSection {
                        LinePlanSectionView(
                            section: mainSection,
                            lineColorHex: lineColorHex
                        )
                    }

                    if !additionalSections.isEmpty {
                        Divider()
                            .padding(.vertical, 16)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(additionalSectionsTitle)
                                .font(.headline)

                            Text("Chaque branche indique la gare exacte où elle rejoint le tronc commun.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.bottom, 8)

                        ForEach(additionalSections) { section in
                            additionalSection(
                                section,
                                showsDivider: section.id != additionalSections.last?.id
                            )
                        }
                    }
                }
                .animation(
                    reduceMotion ? nil : .snappy(duration: 0.28),
                    value: expandedSectionID
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .detailCard()
        .accessibilityElement(children: .contain)
    }

    private func additionalSection(
        _ section: LinePlan.Diagram.Section,
        showsDivider: Bool
    ) -> some View {
        let isExpanded = expandedSectionID == section.id
        let condition = section.stops.compactMap(\.condition)
            .max { $0.severityRank < $1.severityRank }

        return VStack(alignment: .leading, spacing: 0) {
            LineDisclosureRow(
                glyph: .disc(
                    sectionSymbol(for: section),
                    tint: condition?.tint ?? lineColor
                ),
                title: sectionTitle(for: section),
                subtitle: sectionSubtitle(for: section),
                subtitleTint: condition?.tint ?? .secondary,
                isOpen: isExpanded,
                accessibilityLabel: accessibilityLabel(for: section),
                accessibilityValue: isExpanded ? "Dépliée" : "Repliée",
                accessibilityHint: isExpanded
                    ? "Masque les gares de cette branche"
                    : "Affiche les gares de cette branche"
            ) {
                expandedSectionID = isExpanded ? nil : section.id
            }

            if isExpanded {
                LinePlanSectionView(
                    section: section,
                    lineColorHex: lineColorHex,
                    showsHeading: false
                )
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showsDivider {
                Divider()
                    .padding(.leading, 42)
            }
        }
    }

    private var mainSection: LinePlan.Diagram.Section? {
        diagram.sections.first { !$0.stops.isEmpty && $0.role == .main }
            ?? diagram.sections.first { !$0.stops.isEmpty }
    }

    private var additionalSections: [LinePlan.Diagram.Section] {
        diagram.sections.filter { section in
            !section.stops.isEmpty && section.id != mainSection?.id
        }
    }

    private var allStops: [LineSchemaStop] {
        var seen: Set<String> = []
        return diagram.sections.flatMap(\.stops).compactMap { row in
            seen.insert(row.stop.id).inserted ? row.stop : nil
        }
    }

    private var planSummary: String {
        let branchCount = diagram.sections.count { section in
            if case .branch = section.role { true } else { false }
        }
        guard branchCount > 0 else { return "\(allStops.count) gares" }
        let branchLabel = branchCount == 1 ? "1 branche" : "\(branchCount) branches"
        return "\(allStops.count) gares · \(branchLabel)"
    }

    private var additionalSectionsTitle: String {
        additionalSections.count == 1 ? "Branche" : "Branches"
    }

    private func sectionTitle(for section: LinePlan.Diagram.Section) -> String {
        switch section.role {
        case .main:
            "Parcours complémentaire"
        case .branch(let name, _):
            name
        case .loop(let from, let to):
            "Boucle \(from) – \(to)"
        }
    }

    private func sectionSubtitle(for section: LinePlan.Diagram.Section) -> String {
        let stopLabel = section.stops.count == 1
            ? "1 gare"
            : "\(section.stops.count) gares"

        switch section.role {
        case .main:
            return stopLabel
        case .branch(_, let junction):
            guard let junction else { return stopLabel }
            return "\(stopLabel) · Jonction à \(junction)"
        case .loop(let from, let to):
            return "\(stopLabel) · Entre \(from) et \(to)"
        }
    }

    private func sectionSymbol(for section: LinePlan.Diagram.Section) -> String {
        switch section.role {
        case .main: "point.topleft.down.to.point.bottomright.curvepath"
        case .branch: "arrow.triangle.branch"
        case .loop: "arrow.clockwise"
        }
    }

    private func accessibilityLabel(for section: LinePlan.Diagram.Section) -> String {
        "\(sectionTitle(for: section)), \(sectionSubtitle(for: section))"
    }
}

#Preview("RER A — tronc et branches repliables") {
    let detail = PreviewLineStatusRepository.rerADetail
    let diagram = LinePlan.completeDiagram(
        for: detail.schemaDirections,
        disruptions: []
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
