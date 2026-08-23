import SwiftUI

struct NaturalJourneyInputView: View {
  @Binding var query: String
  let isFocused: FocusState<Bool>.Binding
  let errorMessage: String?
  var isEnabled = true
  let onEdit: () -> Void
  let onSubmit: () -> Void
  var onDismiss: (() -> Void)? = nil

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    field
      .frame(maxWidth: .infinity)
  }

  private var field: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center, spacing: 10) {
        Image(systemName: "apple.intelligence")
          .font(.system(size: 21, weight: .medium))
          .foregroundStyle(Color.aiAccent)
          .accessibilityHidden(true)

        TextField(
          "Demander à Metyro…",
          text: $query,
          axis: .vertical,
        )
        .focused(isFocused)
        .lineLimit(1...3)
        .textInputAutocapitalization(.sentences)
        .submitLabel(.search)
        .onSubmit(onSubmit)
        .accessibilityLabel("Description du trajet")
        .onChange(of: query) { _, _ in
          onEdit()
        }

        if !query.isEmpty || onDismiss != nil {
          Button(query.isEmpty ? "Fermer" : "Effacer", systemImage: "xmark") {
            if query.isEmpty {
              onDismiss?()
            } else {
              query = ""
            }
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
          .frame(width: 44, height: 44)
        }
      }
      .padding(.leading, 16)
      .padding(.trailing, 6)
      .padding(.vertical, 5)
      .frame(minHeight: 54)
      .glassEffect(.regular, in: .rect(cornerRadius: Self.fieldRadius))
      .overlay {
        RoundedRectangle(cornerRadius: Self.fieldRadius, style: .continuous)
          .strokeBorder(fieldBorder, lineWidth: 1.5)
      }
      .borderBeam(
        border: Color.aiAccent,
        beam: [.cyan, Color.aiAccent, .pink],
        beamBlur: 9,
        cornerRadius: Self.fieldRadius,
        isEnabled: isEnabled && !reduceMotion,
      )
      .disabled(!isEnabled)

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

  private static let fieldRadius: CGFloat = 27

  private var fieldBorder: Color {
    if errorMessage != nil {
      .red.opacity(0.7)
    } else {
      .clear
    }
  }

}
