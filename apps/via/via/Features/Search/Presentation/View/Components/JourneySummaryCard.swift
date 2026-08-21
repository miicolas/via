import SwiftUI

struct JourneySummaryCard: View {
    let journey: Journey
    let source: JourneyResult.Source?
    var isSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(journey.qualifier.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(journey.qualifier == .recommended ? Color.accentColor : .secondary)

                Spacer(minLength: 8)

                if let status = status {
                    Label(status.title, systemImage: status.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(status.color)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(JourneyFormatting.time(journey.departureAt))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()

                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text(JourneyFormatting.time(journey.arrivalAt))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if routeBadges.isEmpty {
                Label("À pied", systemImage: "figure.walk")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 7) {
                    ForEach(routeBadges) { badge in
                        LineBadgeView(route: badge, size: 24)
                    }

                    if journey.transferCount > 0 {
                        Text(journey.transferCount == 1 ? "1 correspondance" : "\(journey.transferCount) correspondances")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let sourceLabel {
                Label(sourceLabel, systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let accessibility = journey.accessibility {
                PMRBadgeView(accessibilityLabel: accessibility.label, size: 24)
            }

            if !journey.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(journey.warnings.prefix(2), id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.085), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            if isSelected || journey.qualifier == .recommended {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        Color.accentColor.opacity(isSelected ? 0.8 : 0.35),
                        lineWidth: isSelected ? 2.5 : 1.5
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var routeBadges: [RouteBadge] {
        var seen = Set<RouteID>()
        return journey.sections.compactMap(\.route).compactMap { route in
            guard seen.insert(route.id).inserted else { return nil }
            return RouteBadge(
                id: route.id,
                shortName: route.shortName,
                mode: route.mode,
                colorHex: route.colorHex,
                textColorHex: route.textColorHex
            )
        }
    }

    private var summaryText: String {
        var parts = [JourneyFormatting.duration(journey.durationSeconds)]
        let transfers = journey.transferCount == 0
            ? "direct"
            : journey.transferCount == 1
                ? "1 correspondance"
                : "\(journey.transferCount) correspondances"
        parts.append(transfers)
        if journey.walkingDurationSeconds > 0 {
            parts.append("\(JourneyFormatting.duration(journey.walkingDurationSeconds)) de marche")
        }
        return parts.joined(separator: " · ")
    }

    private var sourceLabel: String? {
        guard source == .theoretical || journey.status == .theoretical else { return nil }
        return "Horaires théoriques"
    }

    private var status: JourneyStatus? {
        switch journey.status {
        case .normal, .theoretical:
            nil
        case .disrupted:
            JourneyStatus(
                title: "Perturbé",
                systemImage: "exclamationmark.triangle.fill",
                color: .red
            )
        }
    }

    private var accessibilityLabel: String {
        var value = "\(journey.qualifier.displayName), départ à \(JourneyFormatting.time(journey.departureAt)), arrivée à \(JourneyFormatting.time(journey.arrivalAt)), \(summaryText)"
        if let status { value += ", \(status.title)" }
        if let sourceLabel { value += ", \(sourceLabel)" }
        if let accessibility = journey.accessibility { value += ", \(accessibility.label)" }
        if !journey.warnings.isEmpty { value += ", avertissement: \(journey.warnings.joined(separator: ", "))" }
        return value
    }

}

private struct JourneyStatus {
    let title: String
    let systemImage: String
    let color: Color
}

private extension Journey.Qualifier {
    var displayName: String {
        switch self {
        case .recommended: "Recommandé"
        case .rapid: "Le plus rapide"
        case .lessWalking: "Moins de marche"
        case .comfort: "Le plus simple"
        case .walking: "À pied"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        JourneySummaryCard(
            journey: JourneyResult.mapPreview.journeys[0],
            source: .realtime
        )
        JourneySummaryCard(
            journey: JourneyResult.mapPreview.journeys[1],
            source: .theoretical
        )
    }
    .padding()
}
