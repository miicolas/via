import SwiftUI

struct MeView: View {
    let accountModel: AccountModel
    let authSessionViewModel: AuthSessionViewModel
    let onboardingModel: OnboardingModel
    let searchRepository: any SearchRepository
    let supportDestinations: SupportDestinations
    let onOpenSearch: () -> Void

    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress
    @State private var presentedComingSoon: ComingSoonFeature?
    @State private var isOnboardingPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AccountCardView(
                        account: accountModel,
                        authSession: authSessionViewModel
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                Section("TRAJETS") {
                    NavigationLink {
                        SavedPlacesView(
                            account: accountModel,
                            searchRepository: searchRepository
                        )
                    } label: {
                        Label("Lieux enregistrés", systemImage: "mappin.and.ellipse")
                    }

                    NavigationLink {
                        FavoriteStationsView(
                            account: accountModel,
                            onOpenSearch: onOpenSearch
                        )
                    } label: {
                        Label("Stations favorites", systemImage: "star.fill")
                    }

                    NavigationLink {
                        TransportModesView(account: accountModel)
                    } label: {
                        Label("Modes de transport", systemImage: "tram.fill")
                    }
                }

                Section("COMPTE") {
                    NavigationLink {
                        AccountDataView(
                            account: accountModel,
                            authSession: authSessionViewModel,
                            onboarding: onboardingModel
                        )
                    } label: {
                        Label("Compte et données", systemImage: "person.crop.circle")
                    }

                    NavigationLink {
                        RecentSearchesView(account: accountModel)
                    } label: {
                        Label("Historique des recherches", systemImage: "clock.arrow.circlepath")
                    }

                    AccountExportLink(export: accountModel.makeExport())

                    if authSessionViewModel.isSignedIn {
                        Button("Se déconnecter", role: .destructive) {
                            Task { await authSessionViewModel.signOut() }
                        }
                    }
                }

                Section("SUPPORT") {
                    NavigationLink {
                        SupportView(
                            onboarding: onboardingModel,
                            destinations: supportDestinations
                        )
                    } label: {
                        Label("Aide et support", systemImage: "questionmark.circle")
                    }

                    Button {
                        onboardingModel.reset()
                        isOnboardingPresented = true
                    } label: {
                        Label("Revoir l’introduction", systemImage: "sparkles.rectangle.stack")
                    }
                }

                Section("BIENTÔT") {
                    ComingSoonRow(feature: .notifications) {
                        presentedComingSoon = .notifications
                    }
                    ComingSoonRow(feature: .automations) {
                        presentedComingSoon = .automations
                    }
                    ComingSoonRow(feature: .extensions) {
                        presentedComingSoon = .extensions
                    }
                }
            }
            .navigationTitle("Réglages")
            .toolbarTitleDisplayMode(.inlineLarge)
            .listStyle(.insetGrouped)
        }
        .opacity(tabVisibilityProgress)
        .sheet(item: $presentedComingSoon) { feature in
            ComingSoonView(feature: feature)
                .presentationDetents([.height(250)])
        }
        .sheet(isPresented: $isOnboardingPresented) {
            OnboardingView(model: onboardingModel)
        }
    }
}
