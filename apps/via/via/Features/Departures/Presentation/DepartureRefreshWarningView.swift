import SwiftUI

struct DepartureRefreshWarningView: View {
    var body: some View {
        Label(
            "Mise à jour indisponible — derniers horaires affichés",
            systemImage: "arrow.clockwise.circle"
        )
        .font(.caption.weight(.medium))
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.orange.opacity(0.1))
        }
    }
}
