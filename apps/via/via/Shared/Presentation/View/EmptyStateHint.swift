import SwiftUI

/// The sentence a dead end uses to point at a control living somewhere else on
/// screen.
///
/// Stations wrote this first and it is still the best dead end Via has: no
/// capsule competing with the screen behind it, one grey sentence naming the
/// control, and that control's own symbol set *inline* in the sentence so the
/// eye matches words to toolbar without reading either.
///
/// It stays a sentence even when it is tappable. A prominent capsule here would
/// read as the screen's action, and the action is the control the sentence
/// names — the tap is a shortcut to it, not a second way in. The full-width
/// `primaryAction()` / `secondaryAction()` pair is for a dead end that has
/// something to *do* (retry, choose, authorise), not somewhere to point.
///
/// The interpolated symbol is silent to VoiceOver, so a tappable hint carries
/// its own label: without it the sentence announces a hole where the target is.
struct EmptyStateHint: View {
    private let sentence: Text
    private let label: LocalizedStringKey
    private let action: (() -> Void)?

    /// A hint that only points. The control it names is already reachable, so
    /// tapping the sentence would only duplicate it.
    init(_ sentence: Text, label: LocalizedStringKey) {
        self.sentence = sentence
        self.label = label
        action = nil
    }

    /// A hint that also opens the control it names.
    init(_ sentence: Text, label: LocalizedStringKey, action: @escaping () -> Void) {
        self.sentence = sentence
        self.label = label
        self.action = action
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { sentence }
            } else {
                sentence
            }
        }
        // Grey body text, centred, as wide as the column, tappable without
        // looking it — the metrics belong to this view alone, so they live here
        // rather than as a `View` extension every screen could reach for.
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityLabel(Text(label))
    }
}

#Preview("Vers la recherche") {
    EmptyStateView(EmptyState(title: "Trouvez une station")) {
        EmptyStateHint(
            Text("Touchez \(Image(systemName: "magnifyingglass.circle.fill")) Recherche pour trouver une station près de vous"),
            label: "Ouvrir Recherche pour trouver une station",
            action: {},
        )
    }
    .padding()
}

#Preview("Sans action") {
    EmptyStateView(.noResults(query: "Chatelet")) {
        EmptyStateHint(
            Text("Modifiez \(Image(systemName: "magnifyingglass.circle.fill")) Recherche ci-dessus"),
            label: "Modifiez Recherche ci-dessus",
        )
    }
    .padding()
}
