import SwiftUI

/// The fork between the main spine and one fully visible branch. This is
/// deliberately not a disclosure control: a line plan must reveal its whole
/// shape without asking the rider to open each terminus first.
struct LineBranchRow: View {
    enum Direction: Equatable {
        case joinsTrunk
        case leavesTrunk
    }

    let name: String
    let condition: LineCondition?
    let lineColor: Color
    let direction: Direction

    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 48

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            LineBranchPath(direction: direction)
                .stroke(
                    condition?.tint ?? lineColor,
                    style: StrokeStyle(lineWidth: 26, lineCap: .butt, lineJoin: .round)
                )
                .frame(width: 74, height: height)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Branche \(name)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let condition {
                    Label(condition.title, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(condition.tint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        ["Branche \(name)", condition?.title].compactMap { $0 }.joined(separator: ", ")
    }
}

private struct LineBranchPath: Shape {
    let direction: LineBranchRow.Direction

    func path(in rect: CGRect) -> Path {
        let trunkX: CGFloat = 28
        let branchX: CGFloat = 46
        let startX = direction == .joinsTrunk ? branchX : trunkX
        let endX = direction == .joinsTrunk ? trunkX : branchX
        let curve = rect.midY

        var path = Path()
        path.move(to: CGPoint(x: startX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: endX, y: rect.maxY),
            control1: CGPoint(x: startX, y: curve),
            control2: CGPoint(x: endX, y: curve)
        )
        return path
    }
}

#Preview {
    VStack(spacing: 0) {
        LineBranchRow(
            name: "Cergy le Haut",
            condition: nil,
            lineColor: .red,
            direction: .joinsTrunk
        )
        LineBranchRow(
            name: "Poissy",
            condition: .suspended,
            lineColor: .red,
            direction: .leavesTrunk
        )
    }
    .padding()
}
