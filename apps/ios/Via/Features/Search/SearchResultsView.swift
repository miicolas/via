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
                SearchResultRowView(result: result, action: { onSelect(result) })
            }
        }
    }
}
