import SwiftUI

struct NaturalJourneyFailureView: View {
    let failure: NaturalJourneyFailure
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Le trajet naturel est indisponible", systemImage: "wifi.exclamationmark")
                .font(.headline)
                .foregroundStyle(ViaTheme.critical)
            Text(failure.message)
                .font(.subheadline)
                .foregroundStyle(ViaTheme.body)
            HStack(spacing: 10) {
                ViaButton("Réessayer", systemImage: "arrow.clockwise", action: onRetry)
                ViaButton("Recherche classique", systemImage: "magnifyingglass", action: onCancel)
            }
        }
    }
}
