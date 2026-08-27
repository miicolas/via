import SwiftUI

/// The line badge as the app draws it, rebuilt for the widget extension, which
/// does not link the app's `LineBadgeView`.
struct WidgetLineBadgeView: View {
    let line: WidgetLineStatus
    var size: CGFloat = 32

    var body: some View {
        Text(line.shortName)
            .font(.system(size: max(11, size * 0.5), weight: .bold, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(textColor)
            .frame(minWidth: size, minHeight: size)
            .padding(.horizontal, line.shortName.count > 2 ? 4 : 0)
            .background(lineColor, in: shape)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(line.modeName) ligne \(line.shortName)")
            .accessibilityValue(line.accessibilityValue)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
    }

    private var lineColor: Color { Color(widgetHex: line.colorHex, fallback: .secondary) }
    private var textColor: Color { Color(widgetHex: line.textColorHex, fallback: .white) }
}
