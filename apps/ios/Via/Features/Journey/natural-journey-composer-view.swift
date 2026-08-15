import SwiftUI

struct NaturalJourneyComposerView: View {
    let isDisabled: Bool
    let onSubmit: (String) -> Void

    @State private var query = ""

    init(isDisabled: Bool = false, onSubmit: @escaping (String) -> Void) {
        self.isDisabled = isDisabled
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Décrire un trajet", systemImage: "sparkles")
                .font(ViaFont.headline)
                .foregroundStyle(ViaTheme.ink)
            Text("Écrivez votre demande comme vous la diriez à Via.")
                .font(ViaFont.subheadline)
                .foregroundStyle(ViaTheme.muted)

            TextField("Ex. Comment aller à Châtelet ?", text: $query, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .padding(12)
                .background(ViaTheme.accentSoft)
                .clipShape(.rect(cornerRadius: 14))
                .submitLabel(.go)
                .onSubmit(submit)
                .accessibilityIdentifier("via.naturalJourneyInput")

            ViaButton(
                "Préparer le trajet",
                systemImage: "arrow.triangle.turn.up.right.diamond",
                action: submit
            )
            .disabled(isDisabled || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("via.submitNaturalJourney")
        }
        .padding(16)
        .background(ViaTheme.ground)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private func submit() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isDisabled else { return }
        query = ""
        onSubmit(trimmed)
    }
}
