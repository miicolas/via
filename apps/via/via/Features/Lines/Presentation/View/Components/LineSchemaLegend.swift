import SwiftUI

struct LineSchemaLegend: View {
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            legendItem(
                label: "Service normal",
                icon: AnyView(
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 28, height: 4)
                        .clipShape(Capsule())
                )
            )

            legendItem(
                label: "Travaux / interruption",
                icon: AnyView(
                    HStack(spacing: 4) {
                        DashedLegendRail()
                            .stroke(
                                .secondary,
                                style: StrokeStyle(lineWidth: 3, lineCap: .butt, dash: [4, 3])
                            )
                            .frame(width: 28, height: 4)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                )
            )
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Légende : service normal, trait plein. Travaux ou interruption, trait pointillé avec symbole d’alerte.")
    }

    private func legendItem(label: String, icon: AnyView) -> some View {
        HStack(alignment: .center, spacing: 8) {
            icon
                .accessibilityHidden(true)
            Text(label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DashedLegendRail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
