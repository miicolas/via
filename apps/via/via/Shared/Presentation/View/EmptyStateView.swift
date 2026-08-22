import SwiftUI

/// What Via shows when it has nothing to show: no favourite, no result, no
/// network, no position. There is exactly one of these in the app.
///
/// Before this existed the same sentence changed size, colour and hierarchy
/// depending on which screen it landed on — six columns written six times, plus
/// Apple's `ContentUnavailableView`, which draws its own grey and never offers
/// a way out. A traveller who hits two dead ends in one session should not be
/// able to tell they were built by different hands.
///
/// The column hugs its content: whether it fills the screen is the container's
/// decision, not this view's, so the same component drops into a `List`
/// `Section` and into a full-height overlay without either one deforming.
struct EmptyStateView<Actions: View>: View {
    let state: EmptyState
    /// The way out. Buttons carry `primaryAction()` / `secondaryAction()`, so a
    /// dead end never ends in a pill that hugs its own label.
    @ViewBuilder let actions: Actions

    init(_ state: EmptyState, @ViewBuilder actions: () -> Actions) {
        self.state = state
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: state.emphasis.spacing) {
            if state.isBusy {
                // Searching is not an empty state yet — the dots say so without
                // claiming there is nothing to find.
                LoadingStatus(label: state.title)
            } else {
                if let systemImage = state.systemImage {
                    glyph(systemImage)
                }

                headline
            }

            // An empty `VStack` still takes its padding, and a state with no
            // action would sit on 18 points of nothing.
            if Actions.self != EmptyView.self {
                VStack(spacing: 12) {
                    actions
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: state.emphasis.maxWidth)
        .frame(maxWidth: .infinity)
        .padding(state.emphasis.insets)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Parts

    private var headline: some View {
        VStack(spacing: state.emphasis.textSpacing) {
            Text(state.title)
                .font(state.emphasis.titleFont)
                .foregroundStyle(state.emphasis.titleColor)

            if let message = state.message {
                Text(message)
                    .font(state.emphasis.messageFont)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func glyph(_ systemImage: String) -> some View {
        switch state.emphasis {
        case .standard:
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        case .ai:
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.aiAccent)
                .frame(width: 72, height: 72)
                .glassEffect(.regular.tint(Color.aiSurface), in: .circle)
                .accessibilityHidden(true)
        }
    }
}

extension EmptyStateView where Actions == EmptyView {
    /// A dead end with no way out but the navigation the screen already has.
    init(_ state: EmptyState) {
        self.init(state) { EmptyView() }
    }
}

#Preview("Sans glyphe") {
    EmptyStateView(EmptyState(title: "Trouvez une station")) {
        EmptyStateHint(
            Text("Touchez \(Image(systemName: "magnifyingglass.circle.fill")) Recherche pour trouver une station près de vous"),
            label: "Ouvrir Recherche pour trouver une station",
            action: {},
        )
    }
    .padding()
}

#Preview("Erreur réseau") {
    EmptyStateView(.offline(title: "Lignes indisponibles")) {
        RetryButton(action: {})
            .primaryAction()
    }
    .padding()
}

#Preview("Aucun favori") {
    EmptyStateView(.noFavorites) {
        EmptyStateHint(
            Text("Touchez \(Image(systemName: "star")) sur la fiche d’une station pour la retrouver ici"),
            label: "Touchez l’étoile sur la fiche d’une station pour la retrouver ici",
        )
    }
    .padding()
}

#Preview("Recherche en cours") {
    EmptyStateView(.searching())
        .padding()
}

#Preview("Apple Intelligence") {
    EmptyStateView(
        .ai(
            systemImage: "wifi.exclamationmark",
            title: "Recherche impossible",
            message: "Le service n’a pas répondu. Réessaie dans un instant.",
        ),
    ) {
        RetryButton(action: {})
            .naturalJourneyPrimaryAction()
        Button("Recherche classique", systemImage: "magnifyingglass") {}
            .naturalJourneySecondaryAction()
    }
    .padding()
}
