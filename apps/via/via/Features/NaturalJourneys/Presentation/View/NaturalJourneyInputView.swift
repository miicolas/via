import SwiftUI

struct NaturalJourneyInputView: View {
    @Binding var query: String
    let isFocused: FocusState<Bool>.Binding
    let errorMessage: String?
    let onEdit: () -> Void
    let onSubmit: () -> Void

    private let examples = [
        "Je veux arriver à Châtelet demain avant 9 h",
        "De Nation à La Défense vendredi après 18 h",
        "Gare du Nord vers Orly, sans RER",
    ]

    /// Re-evaluated on every keystroke, so it looks for the first non-blank
    /// character rather than allocating a trimmed copy of the whole phrase.
    private var isSubmittable: Bool {
        query.contains { !$0.isWhitespace && !$0.isNewline }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            field
            examplesSection

            Button("Rechercher", systemImage: "arrow.up", action: onSubmit)
                .naturalJourneyPrimaryAction()
                .disabled(!isSubmittable)

            Label("Traité sur cet iPhone avec Apple Intelligence", systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ThinkingOrb(size: 46, period: 12)

            VStack(alignment: .leading, spacing: 6) {
                Text("Décris ton trajet")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("Les lieux, l’heure et les transports à privilégier ou à éviter, en une phrase.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var field: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            .glassEffect(.regular, in: .rect(cornerRadius: Self.fieldRadius))
            // The focus ring is the only thing telling the traveller the
            // keyboard is aimed at this field; glass alone does not. It traces
            // the glass, so both read their radius from the same constant.
            .overlay {
                RoundedRectangle(cornerRadius: Self.fieldRadius, style: .continuous)
                    .strokeBorder(fieldBorder, lineWidth: 1.5)
            }
            .accessibilityLabel("Description du trajet")
            .onChange(of: query) { _, _ in
                onEdit()
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                    .accessibilityIdentifier("naturalJourneyInputError")
            }
        }
        // Both scopes sit here, on the stack that owns the field and its error,
        // so the two never animate the same label at two different durations.
        .animation(.snappy(duration: 0.2), value: isFocused.wrappedValue)
        .animation(.snappy(duration: 0.2), value: errorMessage)
    }

    private static let fieldRadius: CGFloat = 22

    private var fieldBorder: Color {
        if errorMessage != nil {
            .red.opacity(0.7)
        } else if isFocused.wrappedValue {
            Color.aiAccent.opacity(0.55)
        } else {
            .clear
        }
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exemples")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            GlassEffectContainer(spacing: 8) {
                VStack(spacing: 8) {
                    ForEach(examples, id: \.self) { phrase in
                        NaturalJourneySuggestionRow(phrase: phrase) {
                            query = phrase
                            isFocused.wrappedValue = true
                        }
                    }
                }
            }
        }
    }
}
