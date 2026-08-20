import SwiftUI

struct SearchNoResultsView: View {
    let onChooseAnotherDestination: () -> Void
    let onEditSearch: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            emptySymbol

            Text("Aucun itinéraire trouvé")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            Text("Vérifie ta destination ou ton point de départ. Toujours aucun résultat ?")
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 40)

            Button(action: onChooseAnotherDestination) {
                Label("Choisir une autre destination", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .primaryAction()
            .padding(.top, 28)

            Button(action: onEditSearch) {
                Label("Modifier la recherche", systemImage: "magnifyingglass")
                    .font(.headline)
            }
            .secondaryAction()
            .padding(.top, 12)
        }
        .frame(maxWidth: 340)
        .accessibilityElement(children: .contain)
    }

    private var emptySymbol: some View {
        ZStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 56, weight: .regular))

            Image(systemName: "xmark")
                .font(.headline.weight(.bold))
                .offset(x: -9, y: -9)
        }
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}

#Preview {
    SearchNoResultsView(
        onChooseAnotherDestination: {},
        onEditSearch: {}
    )
    .padding()
}
