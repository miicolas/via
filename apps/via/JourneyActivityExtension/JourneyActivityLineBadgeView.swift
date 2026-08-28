import SwiftUI

/// The line badge as the app draws it, rebuilt for the widget extension, which
/// does not link the app's `LineBadgeView`.
///
/// On the always-on display the system dims the whole activity, so the filled
/// badge is swapped for an outlined one: the line colour and number stay
/// readable instead of sinking into the dimmed background.
struct JourneyActivityLineBadgeView: View {
    let line: JourneyActivityAttributes.LineBadge
    var size: CGFloat = 24

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        let isCompact = line.shortName.count <= 2
        let horizontalPadding: CGFloat = isCompact ? 0 : 4
        let label = Text(line.shortName)
            .font(.system(size: max(11, size * 0.5), weight: .bold, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .truncationMode(.tail)
            .allowsTightening(true)
            .minimumScaleFactor(0.75)
            .foregroundStyle(isLuminanceReduced ? lineColor : textColor)

        Group {
            if isCompact {
                label
                    .frame(width: size, height: size)
            } else {
                label
                    .frame(
                        minWidth: max(0, size - horizontalPadding * 2),
                        maxWidth: max(size, size * 2 - horizontalPadding * 2),
                        minHeight: size
                    )
                    .padding(.horizontal, horizontalPadding)
            }
        }
            .background {
                if isLuminanceReduced {
                    shape.strokeBorder(lineColor, lineWidth: 1.5)
                } else {
                    shape.fill(lineColor)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Ligne \(line.shortName)")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
    }

    private var lineColor: Color { Color(activityHex: line.colorHex, fallback: .blue) }
    private var textColor: Color { Color(activityHex: line.textColorHex, fallback: .white) }
}

extension Color {
    init(activityHex: String?, fallback: Color) {
        guard let activityHex else {
            self = fallback
            return
        }
        let value = activityHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else {
            self = fallback
            return
        }
        self = Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
