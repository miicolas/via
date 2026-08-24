import SwiftUI

/// The whole journey as one horizontal bar: a segment per section, sized by its
/// duration and tinted by its line, filled up to the traveller's position, with
/// the same blue bubble the timeline rail carries riding on top of the fill.
///
/// It is the compact counterpart of the timeline rail — same states, same
/// colours, same bubble — so the header and the list read as one object. This is
/// also the most glanceable answer to "where am I", since the header stays
/// pinned while the timeline scrolls.
struct JourneyProgressBar: View {
    let journey: Journey
    let progress: JourneyProgress
    var height: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Matches `JourneyTimelineRail`'s bubble: a colour no transit line uses.
    private static let knobTint = Color.blue
    private static let segmentSpacing: CGFloat = 3

    var body: some View {
        let segments = segments
        let spacing = CGFloat(max(0, segments.count - 1)) * Self.segmentSpacing

        return GeometryReader { proxy in
            let widths = widths(in: proxy.size.width - spacing, segments: segments)

            ZStack(alignment: .leading) {
                HStack(spacing: Self.segmentSpacing) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(segment.color)
                                    .frame(width: widths[index] * filled(at: index))
                            }
                            .clipShape(Capsule())
                            .frame(width: widths[index])
                    }
                }
                .frame(height: height)

                knob
                    .offset(x: knobOffset(widths: widths, in: proxy.size.width))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: max(height, knobSize))
        .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: progress)
        .accessibilityElement()
        .accessibilityLabel("Progression du trajet")
        .accessibilityValue("\(Int((progress.overallFraction * 100).rounded())) pour cent")
    }

    // MARK: - Bubble

    private var knobSize: CGFloat { height + 10 }

    /// The same badge the rail carries, minus its halo: pinned in a header it
    /// would breathe next to the title all journey long.
    private var knob: some View {
        MarkBadge(
            tint: Self.knobTint,
            size: knobSize,
            isEstimated: !progress.isLocationDerived,
            showsHalo: false
        )
    }

    /// Walks the same layout the segments use, so the bubble lands exactly on
    /// the boundary between filled and unfilled rather than on an average of it.
    private func knobOffset(widths: [CGFloat], in totalWidth: CGFloat) -> CGFloat {
        let current = min(max(0, progress.sectionIndex), max(0, widths.count - 1))
        var travelled: CGFloat = 0

        for index in widths.indices {
            if index < current {
                travelled += widths[index] + Self.segmentSpacing
            } else if index == current {
                travelled += widths[index] * filled(at: index)
                break
            }
        }

        return min(max(0, travelled - knobSize / 2), max(0, totalWidth - knobSize))
    }

    // MARK: - Segments

    private func widths(in contentWidth: CGFloat, segments: [Segment]) -> [CGFloat] {
        segments.map { max(3, contentWidth * $0.weight) }
    }

    private func filled(at index: Int) -> Double {
        if index < progress.sectionIndex { return 1 }
        if index > progress.sectionIndex { return 0 }
        return min(max(0, progress.fractionInSection), 1)
    }

    private var segments: [Segment] {
        let schedule = ActiveJourneyRules.schedule(for: journey)
        let durations = schedule.map { max(1, $0.endsAt.timeIntervalSince($0.startsAt)) }
        let total = durations.reduce(0, +)

        return zip(schedule, durations).map { entry, duration in
            Segment(
                weight: total > 0 ? duration / total : 1 / Double(max(1, schedule.count)),
                color: entry.section.route.map {
                    Color(transitHex: $0.colorHex, fallback: .accentColor)
                } ?? Color.secondary.opacity(0.75)
            )
        }
    }

    private struct Segment {
        let weight: Double
        let color: Color
    }
}

#Preview {
    let journey = Journey.mapPreviewMultipleTransfers

    return VStack(spacing: 28) {
        ForEach([0, 1, 3], id: \.self) { index in
            JourneyProgressBar(
                journey: journey,
                progress: JourneyProgressProjector.progress(
                    schedule: ActiveJourneyRules.schedule(for: journey),
                    sectionIndex: index,
                    at: journey.departureAt.addingTimeInterval(Double(index) * 420 + 120),
                    coordinate: nil,
                    horizontalAccuracy: nil
                )
            )
        }
    }
    .padding()
}
