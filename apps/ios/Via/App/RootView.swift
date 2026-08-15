import SwiftUI

struct RootView: View {
    private let dependencies: AppDependencies

    @AppStorage("via.onboarding.completed.v1") private var onboardingCompleted = false
    @AppStorage("via.anonymous-access.v1") private var anonymousAccessGranted = false
    @State private var router = AppRouter()
    @State private var mapModel: MapFeatureModel
    @State private var chatModel: ChatFeatureModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _mapModel = State(
            initialValue: MapFeatureModel(
                transitAPI: dependencies.transitAPI,
                locationProvider: dependencies.locationProvider
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
    }

    private var shell: some View {
        AppShellView(
            mapModel: mapModel,
            chatModel: chatModel,
            transitAPI: dependencies.transitAPI,
            featureFlags: dependencies.featureFlags,
            router: router,
            navigoClient: dependencies.navigoClient
        )
    }
}
