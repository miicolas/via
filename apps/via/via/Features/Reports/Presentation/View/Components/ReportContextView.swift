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
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Recherche de la station la plus proche…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            case .resolved(let selection):
                Button(action: onChooseStation) {
                    HStack(spacing: 12) {
                        stationLabel(selection)

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.forward")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isEditable)
                .accessibilityLabel("Près de \(selection.station.name)")
                .accessibilityHint("Change la station du signalement")

            case .unavailable(let authorization):
                unavailableContent(
                    title: "Localisation indisponible",
                    message: message(for: authorization),
                    showsRetry: true
                )

            case .empty:
                unavailableContent(
                    title: "Aucune station trouvée",
                    message: "Choisissez la station concernée pour continuer.",
                    showsRetry: false
                )

            case .error(let error):
                unavailableContent(
                    title: "Stations indisponibles",
                    message: message(for: error),
                    showsRetry: true
                )
            }
        }
        .padding(16)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(
            cornerRadius: 20,
            style: .continuous
        ))
    }

    private func stationLabel(_ selection: ReportStationSelection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Près de")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(selection.station.name)
                    .font(.headline)
            }
        }
    }

    private func unavailableContent(
        title: String,
        message: String,
        showsRetry: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "location.slash.fill")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Button("Choisir une station", action: onChooseStation)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isEditable)

                if showsRetry {
                    Button("Réessayer", action: onRetry)
                        .buttonStyle(.bordered)
                        .disabled(!isEditable)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
