import SwiftUI

/// The branch strip: a vertical rail with one bead per station, the way
/// platform screens draw a line. Segments inside an active cut are hatched
/// grey instead of the line color, and the stops bounding a cut are marked —
/// color is never the only carrier.
struct LineSchemaView: View {
    let branch: LineBranch
    let lineColor: Color
    /// Segment `i` joins stops `i` and `i + 1`.
    let cutSegments: Set<Int>
    let affectedStopIDs: Set<String>

    private let railWidth: CGFloat = 6
    private let beadSize: CGFloat = 14
    private let rowHeight: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(branch.stops.enumerated()), id: \.element.id) { index, stop in
                stopRow(index: index, stop: stop)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Schéma de la branche vers \(branch.headsign)")
    }

    private func stopRow(index: Int, stop: LineStop) -> some View {
        let isTerminus = index == 0 || index == branch.stops.count - 1
        let isAffected = affectedStopIDs.contains(stop.id)

        return HStack(alignment: .center, spacing: 14) {
            ZStack {
                VStack(spacing: 0) {
                    segment(cut: cutSegments.contains(index - 1))
                        .opacity(index == 0 ? 0 : 1)
                    segment(cut: cutSegments.contains(index))
                        .opacity(index == branch.stops.count - 1 ? 0 : 1)
                }

                Circle()
                    .strokeBorder(
                        isAffected ? Color.red : lineColor,
                        lineWidth: isTerminus || isAffected ? 4 : 3
                    )
                    .background(Circle().fill(.background))
                    .frame(width: beadSize, height: beadSize)
            }
            .frame(width: beadSize + 6, height: rowHeight)

            Text(stop.name)
                .font(isTerminus ? .subheadline.weight(.bold) : .subheadline)
                .foregroundStyle(isAffected ? .primary : (isTerminus ? .primary : .secondary))
                .lineLimit(1)
                .truncationMode(.middle)

            if isAffected {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Station concernée par une perturbation")
            }

            Spacer(minLength: 0)
        }
        .frame(height: rowHeight)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func segment(cut: Bool) -> some View {
        if cut {
            DashedRail()
                .stroke(
                    Color.secondary,
                    style: StrokeStyle(lineWidth: railWidth - 2, lineCap: .butt, dash: [4, 4])
                )
                .frame(width: railWidth)
                .frame(maxHeight: .infinity)
        } else {
            Rectangle()
                .fill(lineColor)
                .frame(width: railWidth)
                .frame(maxHeight: .infinity)
        }
    }
}

private struct DashedRail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

#Preview {
    let detail = PreviewLineStatusRepository.metro1Detail
    let branch = detail.branches[0]

    ScrollView {
        LineSchemaView(
            branch: branch,
            lineColor: Color(transitHex: detail.route.colorHex, fallback: .secondary),
            cutSegments: branch.cutSegmentIndexes(for: detail.disruptions),
            affectedStopIDs: ["IDFM:71264", "IDFM:71135"]
        )
        .padding()
    }
}
