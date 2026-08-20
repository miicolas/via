import SwiftUI

/// The intermediate stops of one leg, listed on the same rail as the rest of
/// the timeline.
///
/// The previous version nested a `DisclosureGroup` inside another one, which
/// buried arrival times two taps deep. Here the stops simply continue the rail.
struct JourneyStopListView: View {
    let stops: [JourneyStop]
    let rail: JourneyTimelineRailStyle
    let state: JourneyTimelineNodeState

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                HStack(alignment: .top, spacing: 0) {
                    JourneyTimelineRail(
                        above: rail,
                        below: rail,
                        bead: .minor,
                        state: state
                    )

                    Text(stop.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 8)

                    JourneyTimelineTimeLabel(stop: stop)
                }
                .opacity(state == .done ? 0.45 : 1)
                .padding(.vertical, 5)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(label(for: stop))
                // A leg unfolds stop by stop, so expanding it reads as the rail
                // being drawn rather than as a block of text dropping in.
                .staggeredAppearance(rank: index, step: 0.03, limit: 0.3)
            }
        }
    }

    private func label(for stop: JourneyStop) -> String {
        guard let time = stop.arrivalAt ?? stop.departureAt else { return stop.name }
        return "\(stop.name), \(JourneyFormatting.time(time))"
    }
}

/// Trailing time column shared by the stop rows.
private struct JourneyTimelineTimeLabel: View {
    let stop: JourneyStop

    var body: some View {
        Group {
            if let time = stop.arrivalAt ?? stop.departureAt {
                Text(JourneyFormatting.time(time))
            } else {
                Text(verbatim: "")
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 54, alignment: .trailing)
    }
}

#Preview {
    let reference = Date(timeIntervalSince1970: 2_000_000_000)
    let stops = ["Bastille", "Gare de Lyon", "Nation"].enumerated().map { index, name in
        JourneyStop(
            id: "preview:\(index)",
            name: name,
            coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.36),
            arrivalAt: reference.addingTimeInterval(Double(index) * 180),
            departureAt: nil
        )
    }

    return VStack(spacing: 24) {
        JourneyStopListView(stops: stops, rail: .line(colorHex: "FFCE00"), state: .upcoming)
        JourneyStopListView(stops: stops, rail: .line(colorHex: "E3051C"), state: .done)
    }
    .padding()
}
