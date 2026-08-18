import SwiftUI

struct SearchDestinationField: View {
    @Binding var text: String

    let onClear: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            TextField("Station ou adresse", text: $text)
                .font(.title3)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(.secondary.opacity(0.45), in: Circle())
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la destination")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .background(
            Color.secondary.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .onAppear {
            Task { @MainActor in
                isFocused = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Destination")
    }
}

#Preview {
    @Previewable @State var text = ""

    SearchDestinationField(text: $text, onClear: {}, onSubmit: {})
        .padding()
}
