import SwiftUI

struct JourneyEndpointRow: View {
    let label: String
    let prompt: String
    let systemImage: String
    let tint: Color
    let value: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(value ?? prompt)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(value == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(value ?? prompt)")
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 0) {
        JourneyEndpointRow(
            label: "Départ",
            prompt: "Ma position ou un lieu",
            systemImage: "location.fill",
            tint: .blue,
            value: "Ma position",
            onTap: {}
        )

        Divider()
            .padding(.leading, 40)

        JourneyEndpointRow(
            label: "Arrivée",
            prompt: "Où aller ?",
            systemImage: "mappin.and.ellipse",
            tint: .red,
            value: "Châtelet",
            onTap: {}
        )
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .padding()
}
