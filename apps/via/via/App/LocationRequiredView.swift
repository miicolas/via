import SwiftUI
import UIKit

struct LocationRequiredView: View {
    let state: LocationState
    let onRequestLocation: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        let presentation = presentation
        ContentUnavailableView {
            Label(presentation.title, systemImage: systemImage)
        } description: {
            Text(presentation.message)
        } actions: {
            switch presentation.action {
            case .locating:
                ProgressView("Recherche de ta position…")

            case .requestAuthorization:
                Button("Activer la localisation", systemImage: "location.fill") {
                    onRequestLocation()
                }
                .buttonStyle(.borderedProminent)

            case .openSettings:
                Button("Ouvrir les Réglages", systemImage: "gear") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var presentation: LocationRequiredPresentation {
        switch state {
        // `.located` never renders (RootView shows the app content instead);
        // it is folded into the in-progress arm to keep the switch exhaustive.
        case .locating, .idle(authorization: .authorized), .located:
            LocationRequiredPresentation(
                title: "Localisation en cours",
                message: "Via cherche ta position pour afficher la carte et calculer tes itinéraires.",
                action: .locating
            )

        case .failed(.authorized):
            LocationRequiredPresentation(
                title: "Position introuvable",
                message: "Via n’arrive pas à obtenir ta position. Vérifie le signal puis réessaie.",
                action: .requestAuthorization
            )

        case .idle(authorization: .notDetermined), .failed(.notDetermined):
            LocationRequiredPresentation(
                title: "Localisation requise",
                message: "Via a besoin de ta position pour fonctionner. Elle sert à afficher la carte et à calculer tes itinéraires.",
                action: .requestAuthorization
            )

        case .idle(authorization: .restricted),
             .idle(authorization: .denied),
             .failed(.restricted),
             .failed(.denied):
            LocationRequiredPresentation(
                title: "Localisation requise",
                message: "Autorise la localisation dans les Réglages pour accéder à Via.",
                action: .openSettings
            )
        }
    }

    private var systemImage: String {
        switch state {
        case .failed:
            "location.slash.fill"
        case .idle, .locating, .located:
            "location.fill"
        }
    }
}

private struct LocationRequiredPresentation {
    enum Action {
        case locating
        case requestAuthorization
        case openSettings
    }

    let title: String
    let message: String
    let action: Action
}

#Preview("Autorisation") {
    LocationRequiredView(
        state: .idle(authorization: .notDetermined),
        onRequestLocation: {}
    )
}

#Preview("Position indisponible") {
    LocationRequiredView(
        state: .failed(.authorized),
        onRequestLocation: {}
    )
}
