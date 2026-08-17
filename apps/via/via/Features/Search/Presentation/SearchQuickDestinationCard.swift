import SwiftUI

struct SearchQuickDestinationCard: View {
    let recent: RecentSearch
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: recent.kind.iconSystemImage)
                    .font(.headline)
                    .foregroundStyle(recent.kind.iconColor)
                    .frame(width: 30, height: 30)
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
            }
            .frame(width: 148, alignment: .leading)
            .padding(14)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
