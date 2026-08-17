import SwiftUI

struct AuthenticationLoadingView: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 16) {
                ViaSkeleton(.circle)
                    .frame(width: 64, height: 64)

                ViaSkeleton(.capsule)
                    .frame(width: 204, height: 25)

                VStack(spacing: 8) {
                    placeholderBar(width: 262)
                    placeholderBar(width: 226)
                    placeholderBar(width: 244)
                }
            }

            ViaSkeleton(.roundedRectangle(cornerRadius: 14))
                .frame(maxWidth: 340, minHeight: 52, maxHeight: 52)

            ViaLoadingStatus(label: "Ouverture de Via…")

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ouverture de Via…")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func placeholderBar(width: CGFloat) -> some View {
        ViaSkeleton(.capsule)
            .frame(width: width, height: 12)
    }
}
