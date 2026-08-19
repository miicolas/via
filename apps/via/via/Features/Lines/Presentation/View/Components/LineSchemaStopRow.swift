import SwiftUI

/// One station of the schema: rail halves above and below, the bead, the
/// name, the interchange glyph and the disruption pictogram.
struct LineSchemaStopRow: View {
    let row: LineSchemaLayout.StopRow
    let lineColor: Color

    private let railWidth: CGFloat = 6
    private let beadSize: CGFloat = 14
    private let rowHeight: CGFloat = 34

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                VStack(spacing: 0) {
                    rail(row.railAbove)
                    rail(row.railBelow)
                }

                Circle()
                    .strokeBorder(
                        row.condition?.tint ?? lineColor,
                        lineWidth: row.isSectionEnd || row.condition != nil ? 4 : 3
                    )
                    .background(Circle().fill(.background))
                    .frame(width: beadSize, height: beadSize)
            }
            .frame(width: beadSize + 6, height: rowHeight)

            Text(row.stop.name)
                .font(row.isSectionEnd ? .subheadline.weight(.bold) : .subheadline)
                .foregroundStyle(row.condition != nil || row.isSectionEnd ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if row.stop.isInterchange {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Correspondances")
            }

            if let condition = row.condition {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(condition.tint)
                    .accessibilityLabel("Station concernée par une perturbation")
            }

            Spacer(minLength: 0)
        }
        .frame(height: rowHeight)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func rail(_ style: LineSchemaLayout.RailStyle) -> some View {
        switch style {
        case .none:
            Color.clear
                .frame(width: railWidth)
                .frame(maxHeight: .infinity)
        case .line:
            Rectangle()
                .fill(lineColor)
                .frame(width: railWidth)
                .frame(maxHeight: .infinity)
        case .cut(let condition):
            VerticalRail()
                .stroke(
                    condition.tint,
                    style: StrokeStyle(lineWidth: railWidth - 2, lineCap: .butt, dash: [4, 4])
                )
                .frame(width: railWidth)
                .frame(maxHeight: .infinity)
        }
    }
}

private struct VerticalRail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
