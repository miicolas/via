import SwiftUI

struct ChatMessageRowView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 36) }

            Text(message.text)
                .font(.body)
                .foregroundStyle(message.role == .user ? Color.white : ViaTheme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    message.role == .user ? ViaTheme.primary : ViaTheme.accentSoft,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

            if message.role == .assistant { Spacer(minLength: 36) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}
