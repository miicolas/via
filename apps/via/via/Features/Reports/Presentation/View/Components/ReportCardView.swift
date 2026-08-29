import SwiftUI

/// One reportable observation and the single symbol control that submits it.
/// The wording stays readable beside the control instead of turning the whole
/// surface into an easy-to-hit destructive action.
struct ReportCardView: View {
    let title: String
    let systemImage: String
    let tint: Color
    var accessibilityHint: String?
    var accessibilityActionLabel: String?
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                // The adjacent button owns the complete spoken label, so VoiceOver
                // reaches one actionable element rather than reading the row twice.
                .accessibilityHidden(true)

            Spacer(minLength: 8)

            Button(action: action) {
                GlassSquareBadge(tint: tint, size: 44, isInteractive: true) {
                    Image(systemName: isLoading ? "hourglass" : systemImage)
                        .font(.body.weight(.semibold))
                        .stateSymbolTransition(value: isLoading)
                        .animation(reduceMotion ? nil : .default, value: isLoading)
                }
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled || isLoading)
            .accessibilityLabel(accessibilityActionLabel ?? "Signaler \(title)")
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(accessibilityHint ?? "Envoie ce signalement")
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var accessibilityValue: String {
        if isLoading { return "Envoi en cours" }
        return isEnabled ? "Disponible" : "Indisponible"
    }
}

#Preview("Signalement") {
    VStack(spacing: 0) {
        ReportCardView(
            title: "Affluence",
            systemImage: "person.3.fill",
            tint: .red,
            accessibilityHint: "Indiquez le niveau d’occupation que vous observez.",
            action: {}
        )

        Divider()
            .padding(.leading, 16)

        ReportCardView(
            title: "Accès PMR impossible",
            systemImage: "figure.roll",
            tint: .orange,
            accessibilityHint: "Le parcours sans marche n’est pas praticable.",
            isLoading: true,
            action: {}
        )
    }
    .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 22))
    .padding()
}
