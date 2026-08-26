import SwiftUI

struct SearchDestinationField: View {
    @Binding var text: String

    let prompt: String
    let accessibilityLabel: String
    let clearAccessibilityLabel: String
    let onClear: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    init(
        text: Binding<String>,
        prompt: String = "Station ou adresse",
        accessibilityLabel: String = "Destination",
        clearAccessibilityLabel: String = "Effacer la destination",
        onClear: @escaping () -> Void,
        onSubmit: @escaping () -> Void
    ) {
        _text = text
        self.prompt = prompt
        self.accessibilityLabel = accessibilityLabel
        self.clearAccessibilityLabel = clearAccessibilityLabel
        self.onClear = onClear
        self.onSubmit = onSubmit
    }

    @State private var submitTick = 0
    @State private var clearTick = 0

    var body: some View {
        HStack(spacing: 12) {
            TextField(prompt, text: $text)
                .font(.title3)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
                .onSubmit {
                    submitTick += 1
                    onSubmit()
                }
                // The keyboard leaves and a list redraws below the fold: the
                // search is acknowledged where the finger still is.
                .haptic(Haptic.commit, on: submitTick)

            if !text.isEmpty {
                Button {
                    clearTick += 1
                    onClear()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(.secondary.opacity(0.45), in: Circle())
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .haptic(Haptic.cleared, on: clearTick)
                .accessibilityLabel(clearAccessibilityLabel)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .onAppear {
            Task { @MainActor in
                isFocused = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    @Previewable @State var text = ""

    SearchDestinationField(text: $text, onClear: {}, onSubmit: {})
        .padding()
}
