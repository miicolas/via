import SwiftUI

struct ReportContextView: View {
    let state: ReportContextResolutionState
    var isEditable: Bool = true
    let onChooseStation: () -> Void
    let onRetry: () -> Void

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                EmptyStateView(.searching("Recherche de la station la plus proche…"))

            case .resolved(let selection):
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        GlassSquareBadge(tint: .blue, size: 40) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.headline.weight(.semibold))
                        }
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(contextLabel(for: selection.source))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Text(selection.station.name)
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Button(action: onChooseStation) {
                            GlassSquareBadge(tint: .blue, size: 44, isInteractive: true) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!isEditable)
                        .accessibilityLabel("Changer de station")
                        .accessibilityValue(selection.station.name)
                        .accessibilityHint("Choisit une autre station pour le signalement")
                    }

                    if !selection.station.routes.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(selection.station.routes.prefix(5)) { route in
                                LineBadgeView(route: route, size: 20)
                            }

                            if selection.station.routes.count > 5 {
                                LineBadgeOverflowView(
                                    count: selection.station.routes.count - 5,
                                    size: 20
                                )
                            }
                        }
                        .padding(.leading, 52)
                    }
                }
                .padding(14)

            case .unavailable(let authorization):
                unavailableContent(
                    .locationBlocked(
                        title: "Localisation indisponible",
                        message: message(for: authorization),
                    ),
                    showsRetry: true,
                )

            case .empty:
                unavailableContent(
                    EmptyState(
                        systemImage: "mappin.slash",
                        title: "Aucune station trouvée",
                        message: "Choisissez la station concernée pour continuer.",
                    ),
                    showsRetry: false,
                )

            case .error(let error):
                unavailableContent(
                    .offline(title: "Stations indisponibles", message: message(for: error)),
                    showsRetry: true,
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(
            cornerRadius: 20,
            style: .continuous
        ))
    }

    private func contextLabel(for source: ReportStationSelectionSource) -> String {
        switch source {
        case .automatic: "À proximité"
        case .manual: "Station"
        }
    }

    private func unavailableContent(_ state: EmptyState, showsRetry: Bool) -> some View {
        EmptyStateView(state) {
            Button("Choisir une station", systemImage: "mappin.and.ellipse", action: onChooseStation)
                .primaryAction(tint: .blue)
                .disabled(!isEditable)

            if showsRetry {
                RetryButton(action: onRetry)
                    .secondaryAction()
                    .disabled(!isEditable)
            }
        }
    }

    private func message(for authorization: LocationAuthorization) -> String {
        switch authorization {
        case .notDetermined:
            "Autorisez la localisation ou choisissez une station manuellement."
        case .restricted:
            "La localisation est limitée sur cet appareil."
        case .denied:
            "La localisation n’est pas autorisée pour Via."
        case .authorized:
            "La position actuelle n’a pas pu être déterminée."
        }
    }

    private func message(for error: ViaError) -> String {
        switch error {
        case .rateLimited:
            "Le service est momentanément limité."
        case .unavailable, .server:
            "Le service est momentanément indisponible."
        case .invalidConfiguration, .invalidRequest, .transport, .decoding, .unauthorized:
            "Impossible de rechercher les stations pour le moment."
        }
    }
}
