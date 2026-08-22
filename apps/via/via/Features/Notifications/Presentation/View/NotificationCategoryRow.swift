import SwiftUI

struct NotificationCategoryRow: View {
    let preference: NotificationCategoryPreference
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                Image(systemName: preference.category.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(preference.enabled ? .primary : .secondary)
                    .frame(width: 32)

                Text(preference.category.title)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Image(systemName: preference.enabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(preference.enabled ? .green : .secondary)
            }
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preference.category.title)
        .accessibilityValue(preference.enabled ? "Activée" : "Désactivée")
        .accessibilityAddTraits(.isToggle)
    }
}
