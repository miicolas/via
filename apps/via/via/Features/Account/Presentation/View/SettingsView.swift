import SwiftUI

struct SettingsView: View {
    let accountModel: AccountModel
    let searchViewModel: SearchViewModel
    let authSessionViewModel: AuthSessionViewModel
    let profileModel: ProfileModel
    let locationModel: LocationModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("TRAJETS") {
                    NavigationLink {
                        JourneyPreferencesSettingsView(
                            accountModel: accountModel,
                            searchViewModel: searchViewModel
                        )
                    } label: {
                        SettingsRow(
                            title: "Préférences de trajet",
                            systemImage: "slider.horizontal.3",
                            subtitle: "Modes et accessibilité"
                        )
                    }

                    NavigationLink {
                        AppleIntelligenceSettingsView(searchViewModel: searchViewModel)
                    } label: {
                        SettingsRow(
                            title: "Apple Intelligence",
                            systemImage: "sparkles",
                            subtitle: "Recherche en langage naturel",
                            tint: .purple,
                            value: intelligenceStatus
                        )
                    }
                }

                Section("EXTENSIONS") {
                    NavigationLink {
                        LiveActivitiesSettingsView()
                    } label: {
                        SettingsRow(
                            title: "Activités en direct",
                            systemImage: "platter.filled.top.and.arrow.up.iphone",
                            subtitle: "Suivi sur l’écran verrouillé"
                        )
                    }

                    NavigationLink {
                        PermissionsSettingsView(locationModel: locationModel)
                    } label: {
                        SettingsRow(
                            title: "Autorisations iOS",
                            systemImage: "hand.raised.fill",
                            subtitle: "Localisation, caméra et contacts"
                        )
                    }
                }

                Section("GÉRER") {
                    NavigationLink {
                        FavoritesSettingsView(accountModel: accountModel)
                    } label: {
                        SettingsRow(
                            title: "Stations favorites",
                            systemImage: "star.fill",
                            subtitle: "Consulter et supprimer",
                            tint: .orange,
                            value: favoritesCount
                        )
                    }

                    NavigationLink {
                        AccountDataSettingsView(
                            accountModel: accountModel,
                            authSessionViewModel: authSessionViewModel,
                            profileModel: profileModel
                        )
                    } label: {
                        SettingsRow(
                            title: "Données du compte",
                            systemImage: "doc.badge.gearshape",
                            subtitle: "Exporter ou supprimer"
                        )
                    }
                }

                Section("AIDE") {
                    ShareLink(item: feedbackText) {
                        SettingsRow(
                            title: "Envoyer un retour",
                            systemImage: "megaphone.fill"
                        )
                    }
                }

                Section("PLUS") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsRow(
                            title: "À propos",
                            systemImage: "info.circle.fill"
                        )
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }

    private var favoritesCount: String? {
        let count = accountModel.favorites.count
        return count > 0 ? "\(count)" : nil
    }

    private var intelligenceStatus: String {
        switch searchViewModel.naturalLanguageAccess {
        case .active: "Actif"
        case .explanation: "À configurer"
        case .hidden: "Indisponible"
        }
    }

    private var feedbackText: String {
        """
        Retour sur Via

        Version : \(Bundle.main.marketingVersion) (\(Bundle.main.buildNumber))
        Appareil : iOS

        Décris ici ce qui pourrait être amélioré :
        """
    }
}

#Preview("Réglages") {
    let locationModel = LocationModel(
        adapter: InMemoryLocationAdapter(
            coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470)
        )
    )
    let accountModel: AccountModel = {
        let model = AccountModel(
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false
        )
        model.activateAnonymous()
        return model
    }()
    let authSession = StoredAuthSession(
        bearerToken: "preview.token",
        user: AuthUser(
            id: "preview",
            appleUserIdentifier: "preview",
            name: "Alex Martin",
            email: "alex@example.com"
        ),
        expiresAt: .distantFuture,
        lastValidatedAt: .now
    )

    SettingsView(
        accountModel: accountModel,
        searchViewModel: SearchViewModel(
            repository: InMemorySearchRepository.preview,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
            locationModel: locationModel,
            account: accountModel
        ),
        authSessionViewModel: AuthSessionViewModel(
            client: InMemoryAuthenticationClient(session: authSession),
            vault: InMemoryAuthSessionVault(),
            account: accountModel
        ),
        profileModel: ProfileModel(store: InMemoryProfileStore()),
        locationModel: locationModel
    )
}
