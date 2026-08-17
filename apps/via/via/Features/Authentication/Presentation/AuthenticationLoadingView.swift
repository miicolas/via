import SwiftUI

struct AuthenticationLoadingView: View {
    var body: some View {
        ProgressView()
            .controlSize(.regular)
            .tint(.accentColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Chargement de Via")
    }
}
