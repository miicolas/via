import SwiftUI

struct SearchQuickDestinationCard: View {
    let recent: RecentSearch
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: recent.kind.iconSystemImage)
                    .font(.headline)
                    .foregroundStyle(recent.kind.iconColor)
                    .frame(width: 36, height: 36)
                    .background(recent.kind.iconColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(recent.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(width: 210, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                .quaternary.opacity(0.45),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Utiliser \(recent.name)")
    }

    private var context: String {
        guard let context = recent.context, !context.isEmpty else {
            return "Lieu récent"
        }
        return context
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    SearchQuickDestinationCard(
        recent: RecentSearch(
            id: "address:lyon",
            kind: .address,
            name: "Gare de Lyon",
            context: "Paris",
            coordinate: GeoCoordinate(latitude: 48.844, longitude: 2.373),
            savedAt: .now
        ),
        onSelect: {}
    )
    .padding()
}
