import AuthenticationServices
import SwiftUI

struct OnboardingAccountView: View {
    let authSessionViewModel: AuthSessionViewModel
    let onBack: () -> Void
    let onContinueAsGuest: () -> Void

    var body: some View {
        // Same stage as the presentation the traveller has just walked through:
        // the carousel ends, the mark takes the screen, and the panel that was
        // saying "Continuer" now asks for the account. Nothing about the screen
        // announces that a different part of the app has taken over.
        OnboardingScaffold(
            onBack: onBack,
            backHint: "Revient à la présentation de Metyro"
        ) {
            brandMark
        } panel: {
            VStack(spacing: 14) {
                OnboardingHeadline(
                    title: "Garde tes trajets avec toi",
                    subtitle: "Connecte-toi avec Apple pour retrouver tes favoris et tes préférences sur tous tes appareils.",
                    wraps: true
                )

                accountAction

                Text("Metyro ne reçoit jamais ton mot de passe Apple. Tu peux aussi commencer sans compte et te connecter plus tard dans Réglages.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 8)
            .frame(maxWidth: 520)
        }
    }

    /// The presentation's screenshots stop here, so the stage carries the mark
    /// instead — lit from behind so it holds the black rather than floating in it.
    private var brandMark: some View {
        ZStack {
            Circle()
                .fill(.blue)
                .frame(width: 220, height: 220)
                .blur(radius: 90)
                .opacity(0.55)

            Circle()
                .fill(.blue.gradient)
                .frame(width: 132, height: 132)

            Mark()
                .fill(.white)
                .frame(width: 66, height: 66 / Mark.aspectRatio)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Metyro")
    }

    private var accountAction: some View {
        VStack(spacing: 10) {
            AppleSignInButton(authSessionViewModel: authSessionViewModel, style: .white)

            Button("Continuer sans compte", action: onContinueAsGuest)
                .secondaryAction()
                .accessibilityHint("Ouvre Metyro avec un espace local. Tu pourras te connecter plus tard.")
        }
        .padding(.horizontal, 15)
    }
}

#Preview("Connexion Apple") {
    let account = AccountModel(
        remote: InMemoryAccountRemote(),
        synchronizationEnabled: false
    )
    OnboardingAccountView(
        authSessionViewModel: AuthSessionViewModel(
            client: InMemoryAuthenticationClient(session: StoredAuthSession(
                bearerToken: "preview.token",
                user: AuthUser(
                    id: "preview",
                    appleUserIdentifier: "preview",
                    name: "Preview",
                    email: "preview@example.com"
                ),
                expiresAt: .distantFuture,
                lastValidatedAt: .now
            )),
            vault: InMemoryAuthSessionVault(),
            account: account
        ),
        onBack: {},
        onContinueAsGuest: {}
    )
}
