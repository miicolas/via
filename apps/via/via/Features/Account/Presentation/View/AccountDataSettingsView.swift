import CoreTransferable
import SwiftUI

struct AccountDataSettingsView: View {
    let accountModel: AccountModel
    let authSessionViewModel: AuthSessionViewModel
    let profileModel: ProfileModel

    @State private var confirmation: Confirmation?
    @State private var deletionAuthorizer = AppleDeletionAuthorizer()

    var body: some View {
        List {
            Section {
                ShareLink(
                    item: accountModel.makeExport(),
                    preview: SharePreview("Données Via")
                ) {
                    Label("Exporter mes données", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("L’export JSON contient les favoris, lieux, recherches récentes et préférences. Il ne contient aucun identifiant Apple ni jeton de session.")
            }

            Section("SUR CET APPAREIL") {
                Button(role: .destructive) {
                    confirmation = .eraseDevice
                } label: {
                    Label("Effacer les données de cet appareil", systemImage: "iphone.slash")
                }
            }

            if authSessionViewModel.isSignedIn {
                Section("COMPTE VIA") {
                    Button {
                        confirmation = .signOut
                    } label: {
                        Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    Button(role: .destructive) {
                        confirmation = .deleteAccount
                    } label: {
                        Label("Supprimer le compte", systemImage: "trash")
                    }
                }
            }

            if let errorMessage = authSessionViewModel.errorMessage ?? profileModel.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Données du compte")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            confirmation?.title ?? "",
            isPresented: Binding(
                get: { confirmation != nil },
                set: { if !$0 { confirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let confirmation {
                Button(confirmation.actionTitle, role: confirmation.role) {
                    perform(confirmation)
                }
                Button("Annuler", role: .cancel) {}
            }
        } message: {
            Text(confirmation?.message ?? "")
        }
    }

    private func perform(_ confirmation: Confirmation) {
        self.confirmation = nil
        switch confirmation {
        case .eraseDevice:
            Task {
                await authSessionViewModel.eraseDeviceData()
                profileModel.eraseAllProfiles()
            }
        case .signOut:
            Task { await authSessionViewModel.signOut() }
        case .deleteAccount:
            let deletedScope = profileModel.scope
            deletionAuthorizer.authorize { outcome in
                Task {
                    await authSessionViewModel.completeAccountDeletion(outcome)
                    guard !authSessionViewModel.isSignedIn else { return }
                    profileModel.eraseProfile(scope: deletedScope)
                }
            }
        }
    }
}

private enum Confirmation: String, Identifiable {
    case eraseDevice
    case signOut
    case deleteAccount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eraseDevice: "Effacer les données locales ?"
        case .signOut: "Se déconnecter ?"
        case .deleteAccount: "Supprimer définitivement le compte ?"
        }
    }

    var message: String {
        switch self {
        case .eraseDevice:
            "Les profils, favoris, lieux et recherches enregistrés sur cet appareil seront supprimés."
        case .signOut:
            "Les données synchronisées resteront liées à ton compte Via."
        case .deleteAccount:
            "Cette action supprime le compte et ses données synchronisées. Apple demandera une nouvelle confirmation."
        }
    }

    var actionTitle: String {
        switch self {
        case .eraseDevice: "Effacer"
        case .signOut: "Se déconnecter"
        case .deleteAccount: "Continuer avec Apple"
        }
    }

    var role: ButtonRole? {
        switch self {
        case .eraseDevice, .deleteAccount: .destructive
        case .signOut: nil
        }
    }
}
