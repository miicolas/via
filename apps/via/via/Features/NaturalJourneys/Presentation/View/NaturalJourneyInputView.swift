import SwiftUI

struct NaturalJourneyInputView: View {
    @Binding var query: String
    let isFocused: FocusState<Bool>.Binding
    let errorMessage: String?
    let onEdit: () -> Void
    let onSubmit: () -> Void

    /// Re-evaluated on every keystroke, so it looks for the first non-blank
    /// character rather than allocating a trimmed copy of the whole phrase.
    private var isSubmittable: Bool {
        query.contains { !$0.isWhitespace && !$0.isNewline }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Décris le trajet, l’heure ou une préférence.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            field

            Label("Compris sur cet iPhone", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var field: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField(
                    "Ex. Châtelet demain avant 9 h",
                    text: $query,
                    axis: .vertical,
                )
                .focused(isFocused)
                .lineLimit(1 ... 3)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.search)
                .onSubmit(onSubmit)
                .accessibilityLabel("Description du trajet")
                .onChange(of: query) { _, _ in
                    onEdit()
                }

                Button("Rechercher", systemImage: "arrow.up", action: onSubmit)
                    .labelStyle(.iconOnly)
                    .iconAction(isProminent: true)
                    .tint(Color.aiAccent)
                    .disabled(!isSubmittable)
                    .accessibilityHint("Recherche un itinéraire à partir de cette phrase")
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .frame(minHeight: 52)
            .glassEffect(.regular, in: .rect(cornerRadius: Self.fieldRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Self.fieldRadius, style: .continuous)
                    .strokeBorder(fieldBorder, lineWidth: 1.5)
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

    private static let fieldRadius: CGFloat = 18

    private var fieldBorder: Color {
        if errorMessage != nil {
            .red.opacity(0.7)
        } else if isFocused.wrappedValue {
            Color.aiAccent.opacity(0.55)
        } else {
            .clear
        }
    }

}
