import SwiftUI

struct OnboardingAccountView: View {
    let authSessionViewModel: AuthSessionViewModel
    let onContinueAsGuest: () -> Void

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 26) {
                    brandMark

                    VStack(spacing: 10) {
                        Text("Garde tes trajets avec toi")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)

                        Text("Connecte-toi avec Apple pour retrouver tes favoris et tes préférences sur tous tes appareils.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }

                    accountAction

                    Text("Metyro ne reçoit jamais ton mot de passe Apple. Tu peux aussi commencer sans compte et te connecter plus tard dans Réglages.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .padding(.vertical, 36)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var brandMark: some View {
        ZStack {
            Circle()
                .fill(.blue.gradient)
                .frame(width: 86, height: 86)

            Mark()
                .fill(.white)
                .frame(width: 42, height: 42 / Mark.aspectRatio)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Metyro")
    }

    private var accountAction: some View {
        VStack(spacing: 10) {
            AppleSignInButton(authSessionViewModel: authSessionViewModel)

            Button("Continuer sans compte", action: onContinueAsGuest)
                .secondaryAction()
                .accessibilityHint("Ouvre Metyro avec un espace local. Tu pourras te connecter plus tard.")
        }
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
        onContinueAsGuest: {}
    )
}
