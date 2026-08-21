import SwiftUI

struct OnboardingChoiceCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(width: 30, height: 30)
                .background(
                    (isSelected ? Color.accentColor : Color.secondary)
                        .opacity(0.13),
                    in: .circle
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            Button(action: action) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        isSelected
                            ? AnyShapeStyle(Color.accentColor)
                            : AnyShapeStyle(.tertiary)
                    )
                    .contentTransition(
                        reduceMotion
                            ? .identity
                            : .symbolEffect(
                                .replace.magic(fallback: .offUp.byLayer),
                                options: .nonRepeating
                            )
                    )
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(title)
            .accessibilityValue(isSelected ? "Sélectionné" : "Non sélectionné")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            isSelected ? Color.accentColor.opacity(0.10) : Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .frame(minHeight: 54)
    }
}
