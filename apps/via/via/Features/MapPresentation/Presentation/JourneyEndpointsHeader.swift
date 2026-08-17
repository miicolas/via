import SwiftUI

struct JourneyEndpointsHeader: View {
    let model: MapPresentationModel

    var body: some View {
        Button {
            model.send(.focus(.destination))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                Text(destinationName)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(.thinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Modifier la destination, (destinationName)")
    }

    private var destinationName: String {
        let query = model.state.draft.destinationQuery
        return query.isEmpty ? "Où aller ?" : query
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    JourneyEndpointsHeader(model: AppDependencies.preview.root.mapPresentation)
        .padding()
}
