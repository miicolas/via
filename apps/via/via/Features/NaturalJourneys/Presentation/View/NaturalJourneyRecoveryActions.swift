import SwiftUI

/// The two ways out of a state the search could not finish: whatever that state
/// offers as its own first move, then the fall back to the classic search.
///
/// The classic-search leg is built in rather than passed: it is the same glyph
/// and the same sentence on every one of these screens, and a state that
/// restated it could quietly say something else.
struct NaturalJourneyRecoveryActions<Primary: View>: View {
    let onClassicSearch: () -> Void
    @ViewBuilder let primary: Primary

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                primary
                    .naturalJourneyPrimaryAction()
                Button(
                    "Recherche classique",
                    systemImage: "magnifyingglass",
                    action: onClassicSearch,
                )
                .naturalJourneySecondaryAction()
            }
        }
    }
}
