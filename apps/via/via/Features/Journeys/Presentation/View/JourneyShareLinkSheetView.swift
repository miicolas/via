import SwiftUI

/// Gives the sender a clear handoff after the public resource is created. The
/// final destination picker is still Apple's ShareLink, which keeps Messages,
/// AirDrop and Copy Link consistent with the rest of iOS.
struct JourneyShareLinkSheetView: View {
    let link: JourneyShareLink
    let journey: Journey

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 46, weight: .medium))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Lien prêt à partager")
                        .font(.title2.weight(.semibold))
                    Text(routeTitle)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("La personne pourra voir ce trajet sur metyro.app, même sans l’app.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                JourneyShareLinkButton(url: link.url)
                    .primaryAction()

                Text("Lien valable jusqu’au \(JourneyFormatting.dateTime(link.expiresAt))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Fermer", systemImage: "xmark", role: .cancel) {
                    dismiss()
                }
                .secondaryAction()
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Partager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer", systemImage: "xmark", role: .close) {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(36)
        .presentationDragIndicator(.visible)
    }

    private var routeTitle: String {
        let origin = journey.sections.first?.from.name ?? "Départ"
        let destination = journey.sections.last?.to.name ?? "Arrivée"
        return "\(origin) → \(destination)"
    }
}
