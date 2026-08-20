import SwiftUI

struct NaturalJourneyInputView: View {
    @Binding var query: String
    let isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    private let examples = [
        "Je veux arriver à Châtelet demain avant 9 h",
        "De Nation à La Défense vendredi après 18 h",
        "Gare du Nord vers Orly, sans RER",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AIBadge()
            VStack(alignment: .leading, spacing: 8) {
                Text("Décris ton trajet")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("Ajoute les lieux, l’heure et les transports que tu souhaites privilégier ou éviter.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField(
                "Ex. Nation vers La Défense demain avant 9 h",
                text: $query,
                axis: .vertical,
            )
            .focused(isFocused)
            .lineLimit(3 ... 6)
            .textInputAutocapitalization(.sentences)
            .submitLabel(.search)
            .onSubmit(onSubmit)
            .padding(16)
            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
            .accessibilityLabel("Description du trajet")

            VStack(alignment: .leading, spacing: 10) {
                Text("Exemples")
                    .font(.headline)
                ForEach(examples, id: \.self) { phrase in
                    NaturalJourneySuggestionRow(phrase: phrase) {
                        query = phrase
                        isFocused.wrappedValue = true
                    }
                }
            }

            Button("Rechercher", systemImage: "sparkles", action: onSubmit)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(Color.aiAccent)
                .frame(maxWidth: .infinity)
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Label("Traité sur cet iPhone avec Apple Intelligence", systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
