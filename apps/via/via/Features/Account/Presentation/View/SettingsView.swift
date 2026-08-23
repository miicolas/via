import SwiftUI

struct SettingsView: View {
    let accountModel: AccountModel
    let favoriteRoutesModel: FavoriteRoutesModel
    let searchViewModel: SearchViewModel
    let authSessionViewModel: AuthSessionViewModel
    let profileModel: ProfileModel
    let locationModel: LocationModel
    let pushNotificationManager: PushNotificationManager
    let journeyNotificationCoordinator: JourneyNotificationCoordinator
    /// Hands the whole first run back to the root: the carousel, the account
    /// step and the three profile questions replay in order. Owned there
    /// because that is where the flow is branched.
    let onReplayOnboarding: @MainActor () -> Void
    let notificationInboxRemote: any NotificationInboxRemote

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingOnboardingReplay = false

    init(
        accountModel: AccountModel,
        favoriteRoutesModel: FavoriteRoutesModel,
        searchViewModel: SearchViewModel,
        authSessionViewModel: AuthSessionViewModel,
        profileModel: ProfileModel,
        locationModel: LocationModel,
        pushNotificationManager: PushNotificationManager = .preview,
        journeyNotificationCoordinator: JourneyNotificationCoordinator = .preview,
        onReplayOnboarding: @escaping @MainActor () -> Void = {},
        notificationInboxRemote: any NotificationInboxRemote = NoOpNotificationInboxRemote()
    ) {
        self.accountModel = accountModel
        self.favoriteRoutesModel = favoriteRoutesModel
        self.searchViewModel = searchViewModel
        self.authSessionViewModel = authSessionViewModel
        self.profileModel = profileModel
        self.locationModel = locationModel
        self.pushNotificationManager = pushNotificationManager
        self.journeyNotificationCoordinator = journeyNotificationCoordinator
        self.onReplayOnboarding = onReplayOnboarding
        self.notificationInboxRemote = notificationInboxRemote
    }

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
                        NotificationSettingsView(
                            accountModel: accountModel,
                            coordinator: .shared,
                            inboxRemote: notificationInboxRemote,
                            journeyNotificationCoordinator: journeyNotificationCoordinator
                        )
                    } label: {
                        SettingsRow(
                            title: "Notifications",
                            systemImage: "bell.badge.fill",
                            subtitle: "Alertes, rappels et lignes suivies"
                        )
                    }

                    NavigationLink {
                        PermissionsSettingsView(
                            locationModel: locationModel,
                            journeyNotificationCoordinator: journeyNotificationCoordinator
                        )
                    } label: {
                        SettingsRow(
                            title: "Autorisations iOS",
                            systemImage: "hand.raised.fill",
                            subtitle: "Localisation, caméra, contacts et notifications"
                        )
                    }
                }

                Section("GÉRER") {
                    NavigationLink {
                        FavoritesSettingsView(
                            accountModel: accountModel,
                            routesModel: favoriteRoutesModel
                        )
                    } label: {
                        SettingsRow(
                            title: "Favoris",
                            systemImage: "star.fill",
                            subtitle: "Destinations et stations",
                            tint: .orange,
                            value: favoritesCount
                        )
                    }

                    NavigationLink {
                        AccountDataSettingsView(
                            accountModel: accountModel,
                            authSessionViewModel: authSessionViewModel,
                            profileModel: profileModel,
                            onEraseLocalSearches: searchViewModel.clearRecentSearches
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
                    Button {
                        isConfirmingOnboardingReplay = true
                    } label: {
                        SettingsRow(
                            title: "Revoir l’introduction",
                            systemImage: "sparkles.rectangle.stack",
                            subtitle: "Présentation, compte et questions"
                        )
                    }

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
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
            .confirmationDialog(
                "Revoir l’introduction ?",
                isPresented: $isConfirmingOnboardingReplay,
                titleVisibility: .visible
            ) {
                Button("Revoir") {
                    dismiss()
                    onReplayOnboarding()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Metyro repart du premier écran. Ton compte, tes favoris et tes réponses actuelles sont conservés.")
            }
        }
    }

    private var favoritesCount: String? {
        let count = accountModel.favorites.count
            + accountModel.places.count
            + accountModel.destinations.count
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
        Retour sur Metyro

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
        favoriteRoutesModel: FavoriteRoutesModel(
            networkRepository: InMemoryNetworkRepository.mapPreview
        ),
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
