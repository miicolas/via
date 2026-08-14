import SwiftUI

struct RootView: View {
    private let dependencies: AppDependencies

    @AppStorage("via.onboarding.completed.v1") private var onboardingCompleted = false
    @AppStorage("via.authenticated.v1") private var authenticated = false
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
        if dependencies.featureFlags.usesDemoData {
            AppShellView(
                mapModel: mapModel,
                chatModel: chatModel,
                transitAPI: dependencies.transitAPI,
                featureFlags: dependencies.featureFlags
            )
        } else if !onboardingCompleted {
            WelcomeView {
                onboardingCompleted = true
            }
        } else if !authenticated {
            AuthView {
                authenticated = true
            }
        } else {
            AppShellView(
                mapModel: mapModel,
                chatModel: chatModel,
                transitAPI: dependencies.transitAPI,
                featureFlags: dependencies.featureFlags
            )
        }
    }
}
