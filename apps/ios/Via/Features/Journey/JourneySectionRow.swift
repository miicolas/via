import SwiftUI

struct JourneySectionRow: View {
    let section: JourneySection
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(iconColor)
                    .frame(width: 26, height: 26)
                    .background(iconColor.opacity(0.14), in: .circle)
                if !isLast {
                    Rectangle()
                        .fill(ViaTheme.line)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(ViaFont.subheadlineSemibold)
                        .foregroundStyle(ViaTheme.ink)
                    Spacer()
                    Text("\(journeyMinutes(section.durationSeconds)) min")
                        .font(ViaFont.caption.monospacedDigit())
                        .foregroundStyle(ViaTheme.muted)
                }
                Text("\(section.from.name) → \(section.to.name)")
                    .font(ViaFont.caption)
                    .foregroundStyle(ViaTheme.body)
                if let direction = section.direction {
                    Text(direction)
                        .font(ViaFont.caption)
                        .foregroundStyle(ViaTheme.muted)
                }
            }
            .padding(.bottom, isLast ? 0 : 18)
        }
    }

    private var title: String {
        switch section.type {
        case .walk: "Marche"
        case .wait: "Attente"
        case .transfer: "Correspondance"
        case .transit: section.route.map { "Ligne \($0.shortName)" } ?? "Transport"
        }
    }

    private var icon: String {
        switch section.type {
        case .walk: "figure.walk"
        case .wait: "clock"
        case .transfer: "arrow.triangle.swap"
        case .transit: "tram.fill"
        }
    }

    private var iconColor: Color {
        section.route.map { Color(hex: $0.color) } ?? ViaTheme.primary
    }
}
