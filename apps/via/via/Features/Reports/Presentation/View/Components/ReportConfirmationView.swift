import SwiftUI

struct ReportConfirmationView: View {
    let onDone: () -> Void

    var body: some View {
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

                    Text("Votre signalement aidera à améliorer Via à l’avenir.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Pour respecter votre vie privée, aucune adresse e-mail n’est jointe au signalement. Nous ne pouvons donc pas vous répondre.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: .center)
                .padding(24)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Signalement envoyé. Merci. Votre signalement aidera à améliorer Via à l’avenir.")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onDone) {
                Text("Terminé")
                    .frame(maxWidth: .infinity)
            }
                .font(.headline)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.bar)
        }
    }
}
