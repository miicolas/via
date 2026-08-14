import SwiftUI

struct SearchResultsView: View {
    let state: SearchState
    let onSelect: (SearchResult) -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch state {
            case .idle:
                EmptyView()

            case .loading(let previous):
                if previous.isEmpty {
                    ProgressView("Recherche en cours…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    resultList(previous)
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }

            case .ready(let results, let banUnavailable):
                resultList(results)
                if banUnavailable {
                    Label("Les adresses sont momentanément indisponibles.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(ViaTheme.muted)
                }

            case .failed(let previous):
                if previous.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("La recherche n’a pas abouti.", systemImage: "wifi.exclamationmark")
                            .foregroundStyle(ViaTheme.critical)
                        ViaButton("Réessayer", systemImage: "arrow.clockwise", action: onRetry)
                    }
                } else {
                    resultList(previous)
                    ViaButton("Réessayer", systemImage: "arrow.clockwise", action: onRetry)
                }
            }
        }
    }

    @ViewBuilder
    private func resultList(_ results: [SearchResult]) -> some View {
        if results.isEmpty {
            Text("Aucun résultat")
                .font(.subheadline)
                .foregroundStyle(ViaTheme.muted)
        } else {
            ForEach(results) { result in
                ViaButton(action: { onSelect(result) }) {
                    HStack(spacing: 12) {
                        Image(systemName: resultSymbol(for: result))
                            .foregroundStyle(ViaTheme.primary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(ViaTheme.ink)
                            resultContext(result)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ViaTheme.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("via.searchResult.\(result.id)")
            }
        }
    }

    private func resultSymbol(for result: SearchResult) -> String {
        switch result {
        case .station: "tram.fill"
        case .address: "mappin.and.ellipse"
        }
    }

    @ViewBuilder
    private func resultContext(_ result: SearchResult) -> some View {
        switch result {
        case .station(let station):
            HStack(spacing: 4) {
                ForEach(station.routes) { route in
                    LineBadgeView(route: route)
                        .scaleEffect(0.64)
                        .frame(width: 22, height: 22)
                }
                if let distanceMeters = station.distanceMeters {
                    Text(distanceMeters.formatted(.number.precision(.fractionLength(0))) + " m")
                        .font(.caption)
                        .foregroundStyle(ViaTheme.muted)
                }
            }
        case .address(let address):
            Text(address.context)
                .font(.caption)
                .foregroundStyle(ViaTheme.muted)
        }
    }
}
