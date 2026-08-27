import SwiftUI

/// The badge with its condition mark, the tile the Lignes tab shows for a
/// saved line.
struct WidgetLineTile: View {
    let line: WidgetLineStatus
    var size: CGFloat = 32

    var body: some View {
        WidgetLineBadgeView(line: line, size: size)
            .overlay(alignment: .topTrailing) {
                if let indicator = line.indicatorCondition {
                    Image(systemName: line.indicatorSystemImage)
                        .font(.system(size: size * 0.24, weight: .bold))
                        .foregroundStyle(indicator == .attention ? .black : .white)
                        .frame(width: size * 0.44, height: size * 0.44)
                        .background(indicator.tint, in: .circle)
                        .offset(x: size * 0.18, y: -size * 0.18)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(line.modeName) ligne \(line.shortName)")
            .accessibilityValue(line.accessibilityValue)
    }
}
