import SwiftUI

struct LocationPermissionView: View {
    let state: LocationState
    let onRequest: () -> Void
    let onContinueManually: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        switch state {
        case .notDetermined:
            LocationPermissionCardView(
                title: "Trouvez les stations autour de vous",
                message: "Votre position sert uniquement à classer les stations proches et à préparer un trajet.",
                primaryTitle: "Utiliser ma position",
                primarySystemImage: "location.fill",
                primaryAction: onRequest,
                secondaryTitle: "Continuer manuellement",
                secondaryAction: onContinueManually
            )
        case .denied:
            LocationPermissionCardView(
                title: "Position désactivée",
                message: "Vous pouvez continuer avec la recherche. Réactivez la position dans Réglages pour retrouver les stations proches.",
                primaryTitle: "Ouvrir Réglages",
                primarySystemImage: "gear",
                primaryAction: onOpenSettings,
                secondaryTitle: "Continuer manuellement",
                secondaryAction: onContinueManually
            )
        case .manual:
            Label("Mode manuel · recherchez une station ou une adresse", systemImage: "magnifyingglass")
                .font(ViaFont.subheadlineMedium)
                .foregroundStyle(ViaTheme.body)
        case .loading:
            Label("Recherche de votre position…", systemImage: "location.circle")
                .font(ViaFont.subheadlineMedium)
                .foregroundStyle(ViaTheme.body)
        case .ready:
            EmptyView()
        }
    }
}
