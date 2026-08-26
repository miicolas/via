import Charts
import SwiftUI

/// The 24-hour silhouette of one day type. Every bar wears the same muted
/// accent; on today's page the current hour alone turns red, so "now" reads
/// at a glance without a legend.
struct StationCrowdingChart: View {
    let hours: [CrowdingHour]
    let isTodayPage: Bool
    let currentHour: Int

    var body: some View {
        Chart(hours, id: \.hour) { entry in
            BarMark(
                x: .value("Heure", entry.hour),
                y: .value("Affluence", entry.ratio),
                width: .ratio(0.62)
            )
            .foregroundStyle(
                StationCrowdingPresentation.barColor(
                    hour: entry.hour,
                    isTodayPage: isTodayPage,
                    currentHour: currentHour
                )
            )
            .cornerRadius(2.5)
        }
        .chartYScale(domain: 0...1)
        .chartYAxis(.hidden)
        .chartXScale(domain: -0.5...23.5)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hour = value.as(Int.self),
                        let label = StationCrowdingPresentation.axisLabel(for: hour)
                    {
                        Text(label)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Affluence habituelle")
        .accessibilityValue(StationCrowdingPresentation.accessibilitySummary(for: hours))
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
