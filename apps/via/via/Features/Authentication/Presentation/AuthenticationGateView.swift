import AuthenticationServices
import SwiftUI

struct AuthenticationGateView<Content: View>: View {
    @Bindable var viewModel: AuthSessionViewModel
    @ViewBuilder let content: () -> Content
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                AuthenticationLoadingView()

            case .signedOut, .authenticating:
                AppleSignInView(viewModel: viewModel)

            case .authenticated:
                content()
            }
        }
        .task { await viewModel.restore() }
        .sensoryFeedback(trigger: viewModel.state) { oldState, newState in
            switch (oldState, newState) {
            case (.authenticating, .authenticated):
                .success
            default:
                nil
            }
        }
        .sensoryFeedback(.error, trigger: viewModel.errorMessage) { _, newMessage in
            newMessage != nil
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await viewModel.sceneBecameActive() }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: ASAuthorizationAppleIDProvider.credentialRevokedNotification
            )
        ) { _ in
            Task { await viewModel.appleCredentialWasRevoked() }
        }
    }
}

#Preview {
    AuthenticationGateView(viewModel: .preview) {
        Text("Via")
    }
}
