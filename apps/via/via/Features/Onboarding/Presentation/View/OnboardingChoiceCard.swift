import SwiftUI

struct OnboardingChoiceCard: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The whole card is the control, so it is one Button around the layout
        // rather than an invisible full-card button overlaid on it. One line of
        // text and nothing else: the six answers of a question have to stand on
        // the screen together, without a scroll.
        //
        // The colours are stated rather than borrowed from the system: the
        // first run is black whatever the phone's appearance, and a grouped
        // background would sit a shade of black on top of black.
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        isSelected ? AnyShapeStyle(Color.blue) : AnyShapeStyle(.white.opacity(0.14)),
                        in: .circle
                    )

                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.35))
                    .contentTransition(
                        reduceMotion
                            ? .identity
                            : .symbolEffect(
                                .replace.magic(fallback: .offUp.byLayer),
                                options: .nonRepeating
                            )
                    )
                    .frame(width: 28, height: 28)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(minHeight: 52)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Sélectionné" : "Non sélectionné")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .background(
            isSelected ? Color.blue.opacity(0.22) : Color.white.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected ? Color.blue : Color.white.opacity(0.18),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isSelected)
    }
}

#Preview("Réponses") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 8) {
            OnboardingChoiceCard(
                title: "Navigo Annuel",
                systemImage: "calendar.badge.clock",
                isSelected: true,
                action: {}
            )
            OnboardingChoiceCard(
                title: "Navigo Easy ou tickets",
                systemImage: "ticket.fill",
                isSelected: false,
                action: {}
            )
        }
        .padding(30)
    }
    .preferredColorScheme(.dark)
}
