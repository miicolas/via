import SwiftUI

struct JourneySegmentBlock: View {
    let item: JourneySegmentStripModel.Item

    var body: some View {
        content
            .frame(minHeight: 34)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.accessibilityLabel)
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .walk:
            compactChip("figure.walk", text: item.minutesLabel)
        case .wait:
            compactChip("clock.fill", text: item.minutesLabel)
        case .transfer:
            compactChip("arrow.triangle.2.circlepath", text: item.minutesLabel)
        case .walkingOnly:
            Label(item.durationLabel, systemImage: "figure.walk")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(Color.secondary.opacity(0.12), in: Capsule())
        case .transit(let line, let mode, let colorHex, let textColorHex):
            HStack(spacing: 5) {
                if let mode {
                    Image(systemName: mode.chipSystemImage)
                        .font(.caption.weight(.semibold))
                }
                Text(line)
                    .font(.subheadline.weight(.bold))
                Text(item.durationLabel)
                    .font(.subheadline.weight(.medium))
                    .opacity(0.85)
            }
            .foregroundStyle(Color(transitHex: textColorHex, fallback: .white))
            .lineLimit(1)
            .monospacedDigit()
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .background(Color(transitHex: colorHex, fallback: .secondary), in: Capsule())
        }
    }

    private func compactChip(_ systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}
