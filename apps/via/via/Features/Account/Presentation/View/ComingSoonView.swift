import SwiftUI

struct ComingSoonView: View {
    let feature: ComingSoonFeature

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: feature.systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.tint)

            Text(feature.title)
                .font(.title2.weight(.semibold))

            Text(feature.message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Fermer") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDragIndicator(.visible)
    }
}
