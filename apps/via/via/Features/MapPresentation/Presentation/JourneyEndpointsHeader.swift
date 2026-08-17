import SwiftUI

struct JourneyEndpointsHeader: View {
    let destinationName: String
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                Text(destinationName)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(.thinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Modifier la destination, \(destinationName)")
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    JourneyEndpointsHeader(
        destinationName: "Saint-Lazare",
        onEdit: {}
    )
        .padding()
}
