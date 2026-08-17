import SwiftUI

/// Personalized recent row: tinted kind icon, bold title, and a "•"-separated
/// subtitle mixing the place context with recency.
struct RecentSearchRow: View {
    let recent: RecentSearch

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recent.kind.iconSystemImage)
                .font(.headline)
                .foregroundStyle(recent.kind.iconColor)
                .frame(width: 34, height: 34)
                .glassEffect(.regular.tint(recent.kind.iconColor.opacity(0.14)), in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(recent.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var tokens: [String] = []
        if let context = recent.context, !context.isEmpty {
            tokens.append(context)
        } else if recent.kind == .station {
            tokens.append(String(localized: "Station"))
        }
        tokens.append(recent.savedAt.formatted(.relative(presentation: .named)))
        return tokens.joined(separator: " • ")
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 0) {
        RecentSearchRow(recent: RecentSearch(
            id: "station:stop:1",
            kind: .station,
            name: "Châtelet",
            context: nil,
            coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470),
            savedAt: Date(timeIntervalSinceNow: -3_600)
        ))
        Divider()
        RecentSearchRow(recent: RecentSearch(
            id: "address:abc",
            kind: .address,
            name: "12 Rue de Rivoli",
            context: "4e arr., Paris",
            coordinate: GeoCoordinate(latitude: 48.8555, longitude: 2.3600),
            savedAt: Date(timeIntervalSinceNow: -172_800)
        ))
    }
    .padding()
}
