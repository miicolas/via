import SwiftUI

/// A report that can be recognized and sent in one tap.
struct ReportActionView: View {
    let title: String
    let accessibilityTitle: String
    let systemImage: String
    let tint: Color
    let accessibilityHint: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 7) {
            Button(action: action) {
                GlassSquareBadge(tint: tint, size: 56, isInteractive: true) {
                    Image(systemName: isLoading ? "hourglass" : systemImage)
                        .font(.body.weight(.semibold))
                        .stateSymbolTransition(value: isLoading)
                        .animation(reduceMotion ? nil : .default, value: isLoading)
                }
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled || isLoading)
            .accessibilityLabel("Signaler \(accessibilityTitle)")
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(accessibilityHint)

            Text(title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private var accessibilityValue: String {
        if isLoading { return "Envoi en cours" }
        return isEnabled ? "Disponible" : "Indisponible"
    }
}

#Preview("Action rapide") {
    ReportActionView(
        title: "Accès PMR",
        accessibilityTitle: "Accès PMR impossible",
        systemImage: "figure.roll",
        tint: .orange,
        accessibilityHint: "Le parcours sans marche n’est pas praticable.",
        action: {}
    )
    .frame(width: 110)
    .padding()
}
