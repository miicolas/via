import SwiftUI

/// A folded healthy stretch of the schema: the rail runs through and a tap
/// reveals the hidden stations.
struct LineSchemaCollapsedRow: View {
    let run: LineSchemaLayout.CollapsedRun
    let lineColor: Color
    let action: () -> Void

    private let railWidth: CGFloat = 6
    private let beadSize: CGFloat = 14
    private let rowHeight: CGFloat = 30

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: railWidth)
                    .frame(maxHeight: .infinity)
                    .frame(width: beadSize + 6)

                Text("⋯ \(run.hiddenCount) gare\(run.hiddenCount > 1 ? "s" : "")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 0)
            }
            .frame(height: rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Afficher \(run.hiddenCount) gares intermédiaires")
    }
}
