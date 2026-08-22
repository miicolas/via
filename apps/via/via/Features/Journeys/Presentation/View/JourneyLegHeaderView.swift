import SwiftUI

/// Identifies the vehicle a traveller is about to board: line badge, headsign
/// and platform. Sits directly above the boarding stop on the timeline.
struct JourneyLegHeaderView: View {
    let route: JourneyRoute?
    let direction: String?
    let platform: String?
    let durationSeconds: Int
    var isDimmed = false

    var body: some View {
        HStack(spacing: 8) {
            if let route {
                LineBadgeView(route: route.badge, size: 26)
            } else {
                Image(systemName: "tram.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let direction, !direction.isEmpty {
                Label(direction, systemImage: "arrow.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let platform, !platform.isEmpty {
                Label(platform, systemImage: "rectangle.split.3x1")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(JourneyFormatting.duration(durationSeconds))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .opacity(isDimmed ? 0.45 : 1)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        JourneyLegHeaderView(
            route: JourneyRoute(
                id: RouteID(rawValue: "preview:1"),
                shortName: "1",
                longName: "Métro 1",
                mode: .metro,
                colorHex: "FFCE00",
                textColorHex: "000000"
            ),
            direction: "Château de Vincennes",
            platform: "2",
            durationSeconds: 720
        )
        JourneyLegHeaderView(
            route: nil,
            direction: nil,
            platform: nil,
            durationSeconds: 300,
            isDimmed: true
        )
    }
    .padding()
}
