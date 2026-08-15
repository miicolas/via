import SwiftUI

struct RootView: View {
    private let dependencies: AppDependencies

    @AppStorage("via.onboarding.completed.v1") private var onboardingCompleted = false
    @AppStorage("via.anonymous-access.v1") private var anonymousAccessGranted = false
    @State private var router = AppRouter()
    @State private var networkModel: TransitNetworkModel
    @State private var mapModel: MapFeatureModel
    @State private var chatModel: ChatFeatureModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let networkModel = TransitNetworkModel(transitAPI: dependencies.transitAPI)
        _networkModel = State(initialValue: networkModel)
        _mapModel = State(
            initialValue: MapFeatureModel(
                transitAPI: dependencies.transitAPI,
                locationProvider: dependencies.locationProvider,
                recentSearchStore: dependencies.recentSearchStore,
                networkModel: networkModel
            )
        )
        _chatModel = State(
            initialValue: ChatFeatureModel(
                client: dependencies.chatClient,
                locationProvider: dependencies.locationProvider
            )
        )
    }

    var body: some View {
        Group {
            if dependencies.featureFlags.usesDemoData {
                shell
            } else if !onboardingCompleted {
                WelcomeView {
                    onboardingCompleted = true
                }
            } else if dependencies.authenticationClient.availability == .unavailable,
                      !anonymousAccessGranted {
                AuthView {
                    anonymousAccessGranted = true
                }
            } else {
                shell
            }
        }
        .onOpenURL { router.handle($0) }
        .environment(\.font, ViaFont.body)
    }

    private var shell: some View {
        AppShellView(
            networkModel: networkModel,
            mapModel: mapModel,
            chatModel: chatModel,
            transitAPI: dependencies.transitAPI,
            featureFlags: dependencies.featureFlags,
            router: router,
            navigoClient: dependencies.navigoClient
        )
    }
}
