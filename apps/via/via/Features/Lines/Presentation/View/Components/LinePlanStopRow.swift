import SwiftUI

/// One station of the plan: rail halves above and below, the bead, the name,
/// the interchange glyph and the disruption pictogram.
///
/// The rail is drawn the same way as the journey timeline's — a solid core in a
/// soft halo, at the same widths — so a line read from the Lignes tab and a leg
/// read from a trip look like the same object.
struct LinePlanStopRow: View {
    let row: LinePlan.StopRow
    let lineColor: Color
    /// A branch's stations sit one step in from the trunk's, so the fork reads
    /// as a fork and not as the line carrying on.
    var isIndented: Bool = false

    private let railWidth: CGFloat = 11
    private let haloWidth: CGFloat = 22
    private let beadSize: CGFloat = 18

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
                        lineWidth: row.isEnd || row.condition != nil ? 5 : 4
                    )
                    .background(Circle().fill(.background))
                    .frame(width: beadSize, height: beadSize)
                    .background {
                        // A background-coloured gap, so the bead keeps punching
                        // out of a rail thick enough to swallow it.
                        Circle()
                            .fill(.background)
                            .frame(width: beadSize + 7, height: beadSize + 7)
                    }
            }
            .frame(width: haloWidth)
            .frame(minHeight: 44)

            Text(row.stop.name)
                .font(row.isEnd ? .subheadline.weight(.bold) : .subheadline)
                .foregroundStyle(row.condition != nil || row.isEnd ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, row.condition == nil ? 0 : 8)
                .padding(.vertical, row.condition == nil ? 0 : 4)
                .background(row.condition?.tint.opacity(0.10) ?? .clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // No interchange glyph here on purpose: on a Paris metro line four
            // stations in five are one, so the mark carried no information and
            // every row wore it. Correspondances belong to the station screen,
            // where they are named.
            if row.isCutEdge, let condition = row.condition {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(condition.tint)
                    .accessibilityLabel("Début ou fin de la perturbation")
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, isIndented ? 18 : 0)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var labels = [row.stop.name]
        if let condition = row.condition {
            labels.append(condition.title)
        }
        return labels.joined(separator: ", ")
    }

    @ViewBuilder
    private func rail(_ style: LinePlan.RailStyle) -> some View {
        switch style {
        case .none:
            Color.clear
                .frame(width: haloWidth)
                .frame(maxHeight: .infinity)
        case .line:
            solidRail(lineColor)
        case .cut(let condition):
            VerticalRail()
                .stroke(
                    condition.tint,
                    style: StrokeStyle(lineWidth: railWidth - 2, lineCap: .round, dash: [5, 6])
                )
                .frame(width: railWidth)
                .frame(maxHeight: .infinity)
        }
    }

    /// A horizontal gradient rather than a blur, so consecutive rows stack
    /// without a seam between their halves.
    private func solidRail(_ tint: Color) -> some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0), tint.opacity(0.22), tint.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: haloWidth)

            Rectangle()
                .fill(tint)
                .frame(width: railWidth)
        }
        .frame(maxHeight: .infinity)
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
