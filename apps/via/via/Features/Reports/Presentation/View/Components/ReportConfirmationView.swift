import SwiftUI

struct ReportConfirmationView: View {
    let onDone: () -> Void

    var body: some View {
        confirmation
            // The report left the device with nothing else to show for it.
            .hapticOnAppear(Haptic.saved)
    }

    private var confirmation: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(.green)

                        Image(systemName: "checkmark")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    }
                    .frame(width: 88, height: 88)

                    Text("Merci")
                        .font(.largeTitle.weight(.bold))

                    Text("Votre signalement met immédiatement à jour l’information partagée dans Via.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Votre identité est connue de Via pour prévenir les abus, mais elle n’est jamais affichée aux voyageurs.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: .center)
                .padding(24)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Signalement envoyé. Merci. L’information partagée dans Via est mise à jour. Votre identité n’est jamais affichée aux voyageurs.")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Terminé", action: onDone)
                .font(.headline)
                .primaryAction()
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.bar)
        }
    }
}
