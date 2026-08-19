import SwiftUI

/// The complete schema of one direction: a vertical rail with one bead per
/// station, the way platform screens draw a line. Branch sections come under
/// their own title, healthy stretches fold into "⋯ N gares" rows, and
/// segments inside an active cut are dashed and tinted by severity — color is
/// never the only carrier, the dash pattern and the stop pictogram ride along.
struct LineSchemaView: View {
    let rows: [LineSchemaLayout.Row]
    let lineColor: Color
    let directionLabel: String
    let onToggleRun: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                switch row {
                case .sectionHeader(_, let title):
                    LineSchemaSectionHeader(title: title)
                case .stop(let stopRow):
                    LineSchemaStopRow(row: stopRow, lineColor: lineColor)
                case .collapsedRun(let run):
                    LineSchemaCollapsedRow(run: run, lineColor: lineColor) {
                        onToggleRun(run.id)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Schéma de la ligne vers \(directionLabel)")
    }
}

#Preview {
    let detail = PreviewLineStatusRepository.rerADetail
    let direction = detail.schemaDirections[0]

    ScrollView {
        LineSchemaView(
            rows: LineSchemaLayout.rows(
                for: direction,
                disruptions: detail.disruptions,
                expandedRunIDs: []
            ),
            lineColor: Color(transitHex: detail.route.colorHex, fallback: .secondary),
            directionLabel: direction.label,
            onToggleRun: { _ in }
        )
        .padding()
    }
}
