import SwiftUI

struct NaturalJourneyRecoveryActions: View {
    let primarySystemImage: String
    let primaryLabel: LocalizedStringKey
    let primaryAction: () -> Void
    let secondarySystemImage: String
    let secondaryLabel: LocalizedStringKey
    let secondaryAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            actionButton(
                systemImage: primarySystemImage,
                label: primaryLabel,
                foregroundStyle: .white,
                backgroundStyle: Color.aiAccent,
                action: primaryAction
            )
            actionButton(
                systemImage: secondarySystemImage,
                label: secondaryLabel,
                foregroundStyle: Color.primary,
                backgroundStyle: Color.secondary.opacity(0.12),
                action: secondaryAction
            )
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func actionButton(
        systemImage: String,
        label: LocalizedStringKey,
        foregroundStyle: Color,
        backgroundStyle: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(foregroundStyle)
                .frame(width: 52, height: 52)
                .background(backgroundStyle, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
