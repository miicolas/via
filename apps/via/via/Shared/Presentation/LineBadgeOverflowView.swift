import SwiftUI

/// Stands in for the line badges a compact row cannot fit: the same square
/// geometry as `LineBadgeView`, carrying the remaining count instead of a
/// colour, so a station served by a dozen lines still reads as one short row.
struct LineBadgeOverflowView: View {
    let count: Int
    let size: CGFloat

    init(count: Int, size: CGFloat = 22) {
        self.count = count
        self.size = size
    }

    var body: some View {
        Text("+\(count)")
            .font(.system(size: max(10, size * 0.5), weight: .bold, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(.secondary)
            .frame(minWidth: size, minHeight: size)
            .padding(.horizontal, 3)
            .background(
                .quaternary,
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("et \(count) autre\(count > 1 ? "s" : "") ligne\(count > 1 ? "s" : "")")
            .glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
    }
}

#Preview {
    HStack(spacing: 8) {
        LineBadgeOverflowView(count: 3)
        LineBadgeOverflowView(count: 12, size: 14)
    }
    .padding()
}
