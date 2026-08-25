import SwiftUI

/// The information that remains useful when the journey detail is put away.
/// It keeps the map visible without leaving an empty band above the action bar.
struct JourneyCompactSummaryView: View {
    let journey: Journey
    let source: JourneyResult.Source?
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(JourneyFormatting.duration(journey.durationSeconds))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()

                    Text(journey.qualifier.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(journey.qualifier.color)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(JourneyFormatting.time(journey.departureAt))
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                    Text(JourneyFormatting.time(journey.arrivalAt))
                }
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                HStack(spacing: 6) {
                    Text(originName)
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                    Text(destinationName)
                }
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)

                HStack(spacing: 7) {
                    routeSummary
                    Text(transferLabel)
                        .lineLimit(1)

                    if let status {
                        Text(status.title)
                            .foregroundStyle(status.color)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Ouvre le détail du trajet")
    }

    @ViewBuilder
    private var routeSummary: some View {
        if routeBadges.isEmpty {
            Image(systemName: primarySection?.kind.systemImage ?? "figure.walk")
                .accessibilityHidden(true)
        } else {
            ForEach(Array(routeBadges.prefix(3))) { route in
                LineBadgeView(route: route, size: 20)
            }

            if routeBadges.count > 3 {
                Text("+\(routeBadges.count - 3)")
                    .fontWeight(.semibold)
            }
        }
    }

    private var originName: String {
        journey.sections.first?.from.name ?? "Départ"
    }

    private var destinationName: String {
        journey.sections.last?.to.name ?? "Destination"
    }

    private var primarySection: JourneySection? {
        journey.sections.first { $0.kind != .wait && $0.kind != .transfer }
    }

    private var routeBadges: [RouteBadge] {
        var seen = Set<RouteID>()
        return journey.sections.compactMap { section in
            guard let route = section.route, seen.insert(route.id).inserted else { return nil }
            return route.badge
        }
    }

    private var transferLabel: String {
        switch journey.transferCount {
        case 0: "Direct"
        case 1: "1 correspondance"
        default: "\(journey.transferCount) correspondances"
        }
    }

    private var status: (title: String, color: Color)? {
        if journey.status == .disrupted {
            return ("Perturbé", .red)
        }
        if source != .theoretical, journey.status != .theoretical {
            return ("Temps réel", .green)
        }
        return nil
    }

    private var accessibilityLabel: String {
        let qualifier = String(localized: journey.qualifier.displayName)
        let departure = JourneyFormatting.time(journey.departureAt)
        let arrival = JourneyFormatting.time(journey.arrivalAt)
        let duration = JourneyFormatting.duration(journey.durationSeconds)
        var value = "\(qualifier), de \(originName) à \(destinationName), départ à \(departure), arrivée à \(arrival), \(duration), \(transferLabel)"
        if !routeBadges.isEmpty {
            let routes = routeBadges
                .map { "\($0.mode.displayName) \($0.shortName)" }
                .joined(separator: ", ")
            value += ", lignes \(routes)"
        } else if let primarySection {
            value += primarySection.kind == .bike ? ", à vélo" : ", à pied"
        }
        if let status {
            value += ", \(status.title)"
        }
        return value
    }
}

#Preview {
    JourneyCompactSummaryView(
        journey: JourneyResult.mapPreview.journeys[0],
        source: .realtime,
        onExpand: {}
    )
    .padding(.vertical, 12)
    .background(.background)
}
