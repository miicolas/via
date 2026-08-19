import SwiftUI

struct MeView: View {
    let model: AccountHubModel
    let onOpenSearch: () -> Void

    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress
    @State private var presentedComingSoon: ComingSoonFeature?
    @State private var isOnboardingPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AccountCardView(
                        account: model.account,
                        authSession: model.authSession
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                Section("TRAJETS") {
                    NavigationLink {
                        SavedPlacesView(
                            account: model.account,
                            searchPlaces: model.searchPlaces
                        )
                    } label: {
                        Label("Lieux enregistrés", systemImage: "mappin.and.ellipse")
                    }

                    NavigationLink {
                        FavoriteStationsView(
                            account: model.account,
                            onOpenSearch: onOpenSearch
                        )
                    } label: {
                        Label("Stations favorites", systemImage: "star.fill")
                    }

                    NavigationLink {
                        TransportModesView(account: model.account)
                    } label: {
                        Label("Modes de transport", systemImage: "tram.fill")
                    }
                }

                Section("COMPTE") {
                    NavigationLink {
                        AccountDataView(
                            account: model.account,
                            authSession: model.authSession,
                            onboarding: model.onboarding
                        )
                    } label: {
                        Label("Compte et données", systemImage: "person.crop.circle")
                    }

                    NavigationLink {
                        RecentSearchesView(account: model.account)
                    } label: {
                        Label("Historique des recherches", systemImage: "clock.arrow.circlepath")
                    }

                    AccountExportLink(export: model.account.makeExport())

                    if model.authSession.isSignedIn {
                        Button("Se déconnecter", role: .destructive) {
                            Task { await model.authSession.signOut() }
                        }
                    }
                }

                Section("SUPPORT") {
                    NavigationLink {
                        SupportView(
                            onboarding: model.onboarding,
                            destinations: model.supportDestinations
                        )
                    } label: {
                        Label("Aide et support", systemImage: "questionmark.circle")
                    }

                    Button {
                        model.onboarding.reset()
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
            OnboardingView(model: model.onboarding)
        }
    }
}
