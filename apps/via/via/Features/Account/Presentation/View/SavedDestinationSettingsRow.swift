import SwiftUI

struct SavedDestinationSettingsRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isConfigured: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(isConfigured ? Color.accentColor : Color.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .opacity(isConfigured ? 1 : 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isConfigured ? "Configuré" : "À configurer")
    }
}
