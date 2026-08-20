import SwiftUI

/// Persistent reminder that a journey is running, sitting above the tab bar.
///
/// Without it, collapsing the sheet hides every trace of the active journey.
/// Uses the system tab view accessory rather than a bespoke bar, so it inherits
/// the platform's placement, glass material and collapse behaviour.
struct ActiveJourneyAccessoryBar: View {
    let journey: Journey
    let headline: JourneyGuidanceHeadline
    let progress: JourneyProgress
    let action: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    leading

                    VStack(alignment: .leading, spacing: 1) {
                        Text(headline.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if isExpanded, let detail = headline.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(JourneyFormatting.time(journey.arrivalAt))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }

                if isExpanded {
                    JourneyProgressBar(journey: journey, progress: progress, height: 8)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trajet en cours. \(headline.title)")
        .accessibilityHint("Ouvre le guidage du trajet")
    }

    private var isExpanded: Bool {
        placement != .inline
    }

    @ViewBuilder
    private var leading: some View {
        if let route = headline.route {
            LineBadgeView(route: route.badge, size: 24)
        } else {
            Image(systemName: headline.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
        }
    }
}
