import AuthenticationServices
import SwiftUI

struct AppleSignInView: View {
    @Bindable var viewModel: AuthSessionViewModel
    @State private var authorizationAdapter = AppleAuthorizationAdapter()

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "tram.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.tint)

                Text("Bienvenue dans Via")
                    .font(.largeTitle.bold())

                Text("Connecte-toi une première fois en ligne. Ensuite, ta carte et tes données locales resteront accessibles hors connexion.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            SignInWithAppleButton(
                .continue,
                onRequest: authorizationAdapter.configureSignInRequest,
                onCompletion: { result in
                    let outcome = authorizationAdapter.signInOutcome(from: result)
                    Task { await viewModel.completeSignIn(outcome) }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .disabled(viewModel.state == .authenticating)

            if viewModel.state == .authenticating {
                ProgressView("Connexion…")
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("authentication-error")
            }

            Spacer()
        }
        .padding(28)
    }
}

#Preview {
    AppleSignInView(viewModel: .preview)
}
