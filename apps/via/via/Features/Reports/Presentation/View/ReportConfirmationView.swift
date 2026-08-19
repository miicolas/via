import SwiftUI

struct ReportConfirmationView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Image(systemName: "checkmark")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 136, height: 136)
                .background(.green, in: Circle())
                .accessibilityHidden(true)

            Text("Merci")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.primary)
                .padding(.top, 28)

            Text("Votre signalement aidera à améliorer Via à l’avenir.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 26)

            Text("Pour votre confidentialité, les signalements ne contiennent pas votre adresse e-mail et nous ne pouvons donc pas vous répondre.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 54)

            Spacer(minLength: 32)

            Button("Terminé", action: onDone)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(Color.accentColor, in: Capsule())
                .contentShape(Capsule())
                .accessibilityHint("Revient à la liste des signalements")
        }
        .padding(.horizontal, 40)
        .padding(.top, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

#Preview {
    ReportConfirmationView(onDone: {})
        .frame(height: 780)
}
