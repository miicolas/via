import SwiftUI

/// A folded healthy stretch of the schema: the rail runs through and a tap
/// reveals the hidden stations.
struct LineSchemaCollapsedRow: View {
    let run: LineSchemaLayout.CollapsedRun
    let lineColor: Color
    let action: () -> Void

    private let railWidth: CGFloat = 11
    private let haloWidth: CGFloat = 22

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    lineColor.opacity(0),
                                    lineColor.opacity(0.22),
                                    lineColor.opacity(0),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: haloWidth)

                    Rectangle()
                        .fill(lineColor)
                        .frame(width: railWidth)
                }
                .frame(maxHeight: .infinity)
                .frame(width: haloWidth)

                Text("⋯ \(run.hiddenCount) gare\(run.hiddenCount > 1 ? "s" : "")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Afficher \(run.hiddenCount) gares intermédiaires")
    }
}
