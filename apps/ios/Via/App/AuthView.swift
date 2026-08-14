import SwiftUI

struct AuthView: View {
    enum Mode: String {
        case signIn
        case signUp

        var title: String {
            self == .signIn ? "Connexion" : "Créer un compte"
        }

        var actionTitle: String {
            self == .signIn ? "Se connecter" : "Créer mon compte"
        }
    }

    let onAuthenticated: () -> Void

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""

    private var canContinue: Bool {
        email.contains("@") && password.count >= 4
    }

    var body: some View {
        ZStack {
            ViaTheme.ground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(ViaTheme.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(mode.title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(ViaTheme.ink)
                        Text("Retrouvez vos habitudes et préparez vos trajets plus vite.")
                            .font(.body)
                            .foregroundStyle(ViaTheme.body)
                    }

                    VStack(spacing: 12) {
                        TextField("Adresse e-mail", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .padding(14)
                            .background(ViaTheme.line.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityIdentifier("via.auth.email")

                        SecureField("Mot de passe", text: $password)
                            .textContentType(mode == .signIn ? .password : .newPassword)
                            .padding(14)
                            .background(ViaTheme.line.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityIdentifier("via.auth.password")
                    }

                    ViaButton(action: onAuthenticated) {
                        Label {
                            Text(mode.actionTitle)
                        } icon: {
                            Image(systemName: "arrow.right")
                        }
                    }
                        .disabled(!canContinue)
                        .opacity(canContinue ? 1 : 0.45)
                        .accessibilityIdentifier("via.auth.submit")

                    ViaButton(action: {
                        mode = mode == .signIn ? .signUp : .signIn
                    }) {
                        Text(mode == .signIn ? "Créer un compte" : "J’ai déjà un compte")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("via.auth.toggle")
                }
                .padding(28)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
