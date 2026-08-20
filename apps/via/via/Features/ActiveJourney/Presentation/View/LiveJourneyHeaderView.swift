import SwiftUI

/// The sticky guidance banner: what to do now, when you arrive, and how far
/// along the journey you are.
///
/// It stays pinned while the full timeline scrolls underneath, so the traveller
/// can read ahead without losing track of the current step.
struct LiveJourneyHeaderView: View {
    let journey: Journey
    let headline: JourneyGuidanceHeadline
    let progress: JourneyProgress
    var isTracking: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                leading

                VStack(alignment: .leading, spacing: 3) {
                    Text(headline.title)
                        .font(.title3.weight(.bold))
                    if let detail = headline.detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Arrivée")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(JourneyFormatting.time(journey.arrivalAt))
                        .font(.title3.weight(.bold).monospacedDigit())
                }
            }

            JourneyProgressBar(journey: journey, progress: progress)

            if !progress.isLocationDerived && isTracking {
                Label("Progression estimée sur l'horaire", systemImage: "clock.badge.questionmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var leading: some View {
        if let route = headline.route {
            LineBadgeView(route: route.badge, size: 34)
        } else {
            Image(systemName: headline.symbolName)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    let journey = Journey.mapPreviewMultipleTransfers
    let schedule = ActiveJourneyRules.schedule(for: journey)
    let progress = JourneyProgressProjector.progress(
        schedule: schedule,
        sectionIndex: 1,
        at: journey.departureAt.addingTimeInterval(600),
        coordinate: nil,
        horizontalAccuracy: nil
    )

    return LiveJourneyHeaderView(
        journey: journey,
        headline: JourneyGuidance.headline(
            journey: journey,
            schedule: schedule,
            progress: progress,
            at: journey.departureAt.addingTimeInterval(600),
            isPaused: false
        ),
        progress: progress,
        isTracking: true
    )
}
