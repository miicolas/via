import SwiftUI

struct AccountAuthenticationErrorSection: View {
    let message: String?

    @ViewBuilder
    var body: some View {
        if let message {
            Section {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}
