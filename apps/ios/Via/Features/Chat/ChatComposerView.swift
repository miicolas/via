import SwiftUI

struct ChatComposerView: View {
    @Binding var text: String
    let isDisabled: Bool
    let onSend: () -> Void
    let onCancel: () -> Void

    private var canSend: Bool {
        !isDisabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Écrivez à Via…", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(ViaTheme.line.opacity(0.45), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityIdentifier("via.chat.input")

            if isDisabled {
                ViaButton(action: onCancel) {
                    Image(systemName: "stop.fill")
                        .frame(width: 20, height: 20)
                }
                .accessibilityLabel("Arrêter la réponse")
                .accessibilityIdentifier("via.chat.cancel")
            } else {
                ViaButton(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .frame(width: 20, height: 20)
                }
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.45)
                .accessibilityLabel("Envoyer")
                .accessibilityIdentifier("via.chat.send")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
