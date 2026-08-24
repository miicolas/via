import SwiftUI

/// Intermediate stations continue the same wide rail as the boarding and
/// alighting rows. They are real rows, not text nested inside a disclosure.
struct JourneyStopListView: View {
    let stops: [JourneyStop]
    let rail: JourneyTimelineRailStyle
    let state: JourneyTimelineNodeState
    let isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Self.displayedStops(from: stops, isExpanded: isExpanded)) { stop in
                HStack(alignment: .top, spacing: 0) {
                    JourneyTimelineRail(
                        above: rail,
                        below: rail,
                        bead: .minor,
                        state: state
                    )
                    .frame(maxHeight: .infinity)

                    Text(stop.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(rail.lineTint ?? .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 10)
                        .padding(.vertical, 10)
                        .opacity(state == .done ? 0.42 : 1)

                    JourneyTimelineStopTimeLabel(stop: stop)
                        .padding(.vertical, 10)
                        .opacity(state == .done ? 0.42 : 1)
                }
                .frame(minHeight: 58)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(label(for: stop))
            }
        }
    }

    /// In the compact passenger-board state, the last intermediate stop is
    /// always visible: it is the station immediately before the terminus.
    /// Expansion reveals the earlier hidden stations without moving either
    /// endpoint out of the timeline.
    static func displayedStops(
        from stops: [JourneyStop],
        isExpanded: Bool
    ) -> [JourneyStop] {
        isExpanded ? stops : Array(stops.suffix(1))
    }

    private func label(for stop: JourneyStop) -> String {
        guard let time = stop.arrivalAt ?? stop.departureAt else { return stop.name }
        return "\(stop.name), \(JourneyFormatting.time(time))"
    }
}

private struct JourneyTimelineStopTimeLabel: View {
    let stop: JourneyStop

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var time: Date? { stop.arrivalAt ?? stop.departureAt }

    var body: some View {
        Group {
            if let time {
                Text(JourneyFormatting.time(time))
            } else {
                Text(verbatim: "")
            }
        }
        .font(.body.weight(.semibold).monospacedDigit())
        .contentTransition(reduceMotion ? .identity : .numericText())
        .animation(reduceMotion ? nil : .default, value: time)
        .foregroundStyle(.secondary)
        .frame(width: 68, alignment: .trailing)
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

    return JourneyStopListView(
        stops: stops,
        rail: .line(colorHex: "E3051C"),
        state: .upcoming,
        isExpanded: false
    )
    .padding()
}
