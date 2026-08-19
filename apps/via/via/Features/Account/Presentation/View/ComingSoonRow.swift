import SwiftUI

struct ComingSoonRow: View {
    let feature: ComingSoonFeature
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.title)
                    Text("Disponible bientôt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: feature.systemImage)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 44)
        .accessibilityHint("Affiche les informations de disponibilité")
    }
}
