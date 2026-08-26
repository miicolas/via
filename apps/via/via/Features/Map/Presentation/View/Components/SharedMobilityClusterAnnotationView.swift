import SwiftUI

struct SharedMobilityClusterAnnotationView: View {
    let cluster: SharedMobilityCluster

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                SharedMobilityProviderLogoView(provider: cluster.provider, size: 20)
                Text("\(cluster.count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .frame(minHeight: 30)
            .background(Color.accentColor, in: Capsule())
            .overlay { Capsule().stroke(.white.opacity(0.25), lineWidth: 1) }
            .shadow(color: .black.opacity(0.16), radius: 4, y: 2)

            Capsule()
                .fill(.tint)
                .frame(width: 5, height: 8)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(cluster.count) \(cluster.mode.displayName.lowercased())s \(cluster.provider.displayName) regroupés"
        )
        .accessibilityHint("Zoome pour choisir un véhicule")
        .accessibilityAddTraits(.isButton)
    }
}
