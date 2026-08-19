import SwiftUI

struct ReportContextBannerView: View {
    let state: LocationState
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsRetry {
                Button("Réessayer", action: onRetry)
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch state {
        case .located:
            "Contexte automatique activé"
        case .locating:
            "Localisation en cours"
        case .idle:
            "Contexte à confirmer"
        case .failed:
            "Localisation indisponible"
        }
    }

    private var message: String {
        switch state {
        case .located:
            "Votre position sera associée au signalement, sans conserver votre GPS précis."
        case .locating:
            "Via recherche la station ou le trajet le plus probable."
        case .idle:
            "La position sera demandée pour enrichir l’observation."
        case .failed:
            "Vous pouvez signaler sans position, mais le contexte sera moins précis."
        }
    }

    private var iconName: String {
        switch state {
        case .located:
            "location.fill"
        case .locating:
            "location"
        case .idle:
            "location.slash"
        case .failed:
            "location.slash"
        }
    }

    private var iconColor: Color {
        switch state {
        case .located:
            .green
        case .locating:
            .blue
        case .idle, .failed:
            .orange
        }
    }

    private var showsRetry: Bool {
        if case .located = state { return false }
        if case .locating = state { return false }
        return true
    }
}
