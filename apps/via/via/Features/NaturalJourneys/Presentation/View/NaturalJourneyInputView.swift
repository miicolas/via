import SwiftUI

struct NaturalJourneyInputView: View {
  @Binding var query: String
  let isFocused: FocusState<Bool>.Binding
  let errorMessage: String?
  var isThinking = false
  let onEdit: () -> Void
  let onSubmit: () -> Void
  var onDismiss: (() -> Void)? = nil

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // Valeur écrite par l'interception du "\n" : son onChange ré-entrant ne doit
  // pas repasser par onEdit, qui sortirait l'écran de l'état .loading.
  @State private var newlineStrippedQuery: String?

  var body: some View {
    field
      .frame(maxWidth: .infinity)
  }

  private var field: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center, spacing: 10) {
        if isThinking {
          ThinkingSpinner(size: 21)
            .transition(swapTransition)
        } else {
          Image(systemName: "apple.intelligence")
            .font(.system(size: 21, weight: .medium))
            .foregroundStyle(Color.aiAccent)
            .accessibilityHidden(true)
            .transition(swapTransition)
        }

        if isThinking {
          // A shimmer over the phrase rather than a greyed-out disabled field:
          // the request itself is what Metyro is thinking about.
          Text(query)
            .aiShimmer()
            .lineLimit(1...3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(swapTransition)
            .accessibilityLabel("Metyro réfléchit à ta demande")
            .accessibilityAddTraits(.updatesFrequently)
        } else {
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
          .transition(swapTransition)
          .onChange(of: query) { _, newValue in
            if newValue == newlineStrippedQuery {
              newlineStrippedQuery = nil
              return
            }
            newlineStrippedQuery = nil
            // Avec axis: .vertical, la touche retour insère "\n" au lieu de
            // déclencher onSubmit : on l'intercepte ici pour lancer la recherche.
            guard newValue.contains("\n") else {
              onEdit()
              return
            }
            let cleaned = newValue
              .replacingOccurrences(of: "\n", with: " ")
              .trimmingCharacters(in: .whitespaces)
            newlineStrippedQuery = cleaned
            query = cleaned
            if !cleaned.isEmpty {
              onSubmit()
            }
          }
        }

        if isThinking || !query.isEmpty || onDismiss != nil {
          Button(dismissTitle, systemImage: "xmark") {
            if isThinking || query.isEmpty {
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

        if canSend {
          Button("Envoyer", systemImage: "arrow.up") {
            onSubmit()
          }
          .labelStyle(.iconOnly)
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.white)
          .buttonStyle(.plain)
          .frame(width: 34, height: 34)
          .background(Circle().fill(Color.aiAccent))
          .contentShape(Circle())
          .frame(width: 44, height: 44)
          .transition(swapTransition)
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
      // The beam never switches off while the field is visible: it brightens
      // while Metyro thinks instead of freezing at the exact moment work
      // starts.
      .borderBeam(
        border: Color.aiAccent,
        beam: [.cyan, Color.aiAccent, .pink],
        beamBlur: isThinking ? 14 : 9,
        cornerRadius: Self.fieldRadius,
        isEnabled: !reduceMotion,
      )

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
    .animation(.snappy(duration: 0.2), value: canSend)
    .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: isThinking)
  }

  /// Le clavier soumet déjà via la touche retour ; ce bouton est l'équivalent
  /// visible, donc il n'apparaît que quand il y a réellement une phrase à envoyer.
  private var canSend: Bool {
    !isThinking && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var swapTransition: AnyTransition {
    reduceMotion ? .opacity : AnyTransition(.blurReplace)
  }

  private var dismissTitle: String {
    if isThinking {
      "Annuler la recherche"
    } else if query.isEmpty {
      "Fermer"
    } else {
      "Effacer"
    }
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
