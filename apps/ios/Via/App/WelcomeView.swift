import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            ViaTheme.ground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                Image(systemName: "tram.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(ViaTheme.primary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Vos trajets,\navec Via.")
                        .font(ViaFont.display)
                        .foregroundStyle(ViaTheme.ink)
                    Text("Une carte claire, des départs en direct et un assistant qui comprend vos déplacements.")
                        .font(ViaFont.title3)
                        .foregroundStyle(ViaTheme.body)
                }

                Spacer()

                ViaButton("Commencer", systemImage: "arrow.right", action: onContinue)
                    .accessibilityIdentifier("via.onboarding.continue")
            }
            .padding(28)
        }
    }
}
