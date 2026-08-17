import AuthenticationServices
import SwiftUI

struct AppleSignInView: View {
    @Bindable var viewModel: AuthSessionViewModel
    @State private var authorizationAdapter = AppleAuthorizationAdapter()

    var body: some View {
        LoopOnBoarding(
            config: .init(
                tint: .accentColor,
                pulseTint: Color.accentColor.opacity(0.65),
                bottomContentPadding: 145
            ),
            phases: [
                .init(
                    symbol: "tram.fill",
                    title: "Bienvenue dans Via",
                    description: "Connecte-toi une première fois en ligne.\nTa carte et tes données restent accessibles hors connexion."
                )
            ]
        ) {
            VStack(spacing: 12) {
                SignInWithAppleButton(
                    .continue,
                    onRequest: authorizationAdapter.configureSignInRequest,
                    onCompletion: { result in
                        let outcome = authorizationAdapter.signInOutcome(from: result)
                        Task { await viewModel.completeSignIn(outcome) }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .disabled(viewModel.state == .authenticating)

                if viewModel.state == .authenticating {
                    ViaLoadingStatus(label: "Connexion…")
                        .transition(.opacity)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("authentication-error")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AppleSignInView(viewModel: .preview)
}
