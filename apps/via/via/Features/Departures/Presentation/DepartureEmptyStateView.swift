import SwiftUI

struct DepartureEmptyStateView: View {
    let source: DepartureBoard.Source

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: source == .unavailable ? "wifi.exclamationmark" : "clock")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var title: String {
        source == .unavailable
            ? "Horaires indisponibles"
            : "Aucun passage à venir"
    }

    private var message: String {
        source == .unavailable
            ? "Les prochains passages ne sont pas disponibles pour le moment."
            : "Aucun prochain passage n’est annoncé à cette station."
    }
}
