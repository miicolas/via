import Charts
import SwiftUI

/// The 24-hour silhouette of one day type: capsule bars fading towards the
/// baseline over a soft area echo of the same curve. The bars rise from the
/// baseline on arrival and morph in place when the day changes; on today's
/// page the current hour alone turns red, so "now" reads at a glance without
/// a legend.
struct StationCrowdingChart: View {
    let hours: [CrowdingHour]
    let isTodayPage: Bool
    let currentHour: Int

    /// 0 until the chart has appeared, so the bars grow out of the baseline.
    /// Reduced motion skips the growth and renders the final state directly.
    @State private var growth: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Chart {
            ForEach(hours, id: \.hour) { entry in
                AreaMark(
                    x: .value("Heure", entry.hour),
                    y: .value("Affluence", entry.ratio * growth)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(silhouette)

                BarMark(
                    x: .value("Heure", entry.hour),
                    y: .value("Affluence", entry.ratio * growth),
                    // `.ratio` renders zero-width bars on the iOS 27 beta; an
                    // inset from the ~14.6 pt hour step keeps the same 0.62
                    // proportion.
                    width: .inset(2.8)
                )
                .foregroundStyle(barGradient(for: entry))
                .cornerRadius(4.5)
            }
        }
        .chartYScale(domain: 0...1)
        .chartYAxis(.hidden)
        .chartXScale(domain: -0.5...23.5)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18]) { value in
                AxisGridLine()
                    .foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let hour = value.as(Int.self),
                        let label = StationCrowdingPresentation.axisLabel(for: hour)
                    {
                        Text(label)
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .bouncy(duration: 0.45), value: hours)
        .animation(reduceMotion ? nil : .default, value: isTodayPage)
        .onAppear {
            if reduceMotion {
                growth = 1
            } else {
                withAnimation(.bouncy(duration: 0.55)) { growth = 1 }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Affluence habituelle")
        .accessibilityValue(StationCrowdingPresentation.accessibilitySummary(for: hours))
    }

    /// Each capsule fades towards the baseline so the silhouette stays airy;
    /// the accent (or the red "now") lives at the top where the eye reads it.
    private func barGradient(for entry: CrowdingHour) -> LinearGradient {
        let base = StationCrowdingPresentation.barColor(
            hour: entry.hour,
            isTodayPage: isTodayPage,
            currentHour: currentHour
        )
        return LinearGradient(
            colors: [base, base.opacity(0.25)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// The smoothed echo of the same curve, faint enough to read as a glow
    /// under the bars rather than as a second dataset.
    private var silhouette: LinearGradient {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.16), Color.accentColor.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    VStack(spacing: 24) {
        StationCrowdingChart(
            hours: StationCrowding.preview.weekday,
            isTodayPage: true,
            currentHour: 17
        )
        StationCrowdingChart(
            hours: StationCrowding.preview.sunday,
            isTodayPage: false,
            currentHour: 17
        )
    }
    .frame(height: 300)
    .padding()
}
