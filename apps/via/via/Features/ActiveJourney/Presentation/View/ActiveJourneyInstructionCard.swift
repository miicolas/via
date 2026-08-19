import SwiftUI

struct ActiveJourneyInstructionCard: View {
    let eyebrow: String
    let instruction: ActiveJourneyInstruction
    var emphasized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(emphasized ? Color.accentColor : .secondary)

            HStack(alignment: .top, spacing: 13) {
                icon

                VStack(alignment: .leading, spacing: 5) {
                    Text(instruction.title)
                        .font(emphasized ? .title3.weight(.bold) : .headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail = instruction.detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(
                        "\(JourneyFormatting.time(instruction.startsAt)) – " +
                            JourneyFormatting.time(instruction.endsAt)
                    )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            emphasized ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.065),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        if let route = instruction.route {
            LineBadgeView(
                route: RouteBadge(
                    id: route.id,
                    shortName: route.shortName,
                    mode: route.mode,
                    colorHex: route.colorHex,
                    textColorHex: route.textColorHex
                ),
                size: 32
            )
        } else {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(emphasized ? Color.accentColor : .secondary)
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1), in: Circle())
                .accessibilityHidden(true)
        }
    }

    private var systemImage: String {
        switch instruction.sectionKind {
        case .walk: "figure.walk"
        case .wait: "clock"
        case .transfer: "arrow.triangle.turn.up.right.diamond"
        case .transit: "tram.fill"
        }
    }
}
