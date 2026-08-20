import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult
    let accessibilityHint: String
    let action: () -> Void

    init(
        result: SearchResult,
        accessibilityHint: String = "Sélectionne cette destination",
        action: @escaping () -> Void
    ) {
        self.result = result
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                resultIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    resultDetails
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.forward")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    @ViewBuilder
    private var resultIcon: some View {
        switch result {
        case .station(let station):
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))

                Image(systemName: station.routes.first?.mode.chipSystemImage ?? "tram.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 46, height: 46)

        case .address:
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.14))

                Image(systemName: "mappin.and.ellipse")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 46, height: 46)
        }
    }

    @ViewBuilder
    private var resultDetails: some View {
        switch result {
        case .station(let station):
            VStack(alignment: .leading, spacing: 6) {
                if station.routes.isEmpty {
                    Text("Station")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 6) {
                        ForEach(station.routes.prefix(3)) { route in
                            LineBadgeView(route: route, size: 20)
                        }
                    }
                }
            }

        case .address(let address):
            Text(address.context.isEmpty ? "Adresse" : address.context)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var accessibilityLabel: String {
        switch result {
        case .station(let station):
            let routes = station.routes.map(\.shortName).joined(separator: ", ")
            let base = routes.isEmpty ? "Station \(station.name)" : "Station \(station.name), lignes \(routes)"
            return base
        case .address(let address):
            return address.context.isEmpty
                ? "Adresse \(address.name)"
                : "Adresse \(address.name), \(address.context)"
        }
    }
}

#Preview {
    SearchResultRow(result: .previewStation, action: {})
        .padding(.horizontal)
}
