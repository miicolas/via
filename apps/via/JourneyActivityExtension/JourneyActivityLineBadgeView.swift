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
        Text(line.shortName)
            .font(.system(size: max(11, size * 0.5), weight: .bold, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(isLuminanceReduced ? lineColor : textColor)
            .frame(minWidth: size, minHeight: size)
            .padding(.horizontal, line.shortName.count > 2 ? 4 : 0)
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
