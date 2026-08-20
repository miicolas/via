import SwiftUI

struct JourneyDetailSummaryView: View {
    let journey: Journey
    let source: JourneyResult.Source?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(JourneyFormatting.time(journey.departureAt))
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text(journey.sections.first?.from.name ?? "Départ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "arrow.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(JourneyFormatting.time(journey.arrivalAt))
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text(journey.sections.last?.to.name ?? "Arrivée")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    summaryFacts
                }

                VStack(alignment: .leading, spacing: 7) {
                    summaryFacts
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)

            if !routeBadges.isEmpty {
                HStack(spacing: 7) {
                    ForEach(routeBadges) { badge in
                        LineBadgeView(route: badge, size: 27)
                    }
                }
            }

            if source == .theoretical || journey.status == .theoretical {
                Label("Horaires théoriques", systemImage: "clock.badge.questionmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if journey.status == .disrupted {
                Label("Trajet perturbé", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var transferText: String {
        switch journey.transferCount {
        case 0: "Direct"
        case 1: "1 correspondance"
        default: "\(journey.transferCount) correspondances"
        }
    }

    @ViewBuilder
    private var summaryFacts: some View {
        Label(JourneyFormatting.duration(journey.durationSeconds), systemImage: "clock")
        Label(transferText, systemImage: "arrow.triangle.branch")
        if journey.walkingDurationSeconds > 0 {
            Label(JourneyFormatting.duration(journey.walkingDurationSeconds), systemImage: "figure.walk")
        }
    }

    private var routeBadges: [RouteBadge] {
        var seen = Set<RouteID>()
        return journey.sections.compactMap(\.route).compactMap { route in
            guard seen.insert(route.id).inserted else { return nil }
            return route.badge
        }
    }
}
