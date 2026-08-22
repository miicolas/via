import SwiftUI

struct JourneySummaryCard: View {
    let journey: Journey
    let source: JourneyResult.Source?
    var isSelected = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let displayedRouteBadges = routeBadges
        let visibleRouteBadgeCount = maximumVisibleRouteBadges
        let hiddenRouteBadgeCount = max(0, displayedRouteBadges.count - visibleRouteBadgeCount)

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

            if displayedRouteBadges.isEmpty {
                Label("À pied", systemImage: "figure.walk")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 7) {
                    ForEach(displayedRouteBadges.prefix(visibleRouteBadgeCount)) { badge in
                        LineBadgeView(route: badge.route, size: 24)
                    }

                    if hiddenRouteBadgeCount > 0 {
                        LineBadgeOverflowView(count: hiddenRouteBadgeCount, size: 24)
                    }
                }
            }

            if let sourceLabel {
                Label(sourceLabel, systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if journey.accessibility != nil || journey.peak != nil {
                HStack(spacing: 8) {
                    if let accessibility = journey.accessibility {
                        PMRBadgeView(
                            condition: accessibility.condition,
                            label: accessibility.label,
                            size: 24,
                            isInteractive: false
                        )
                    }

                    if let peak = journey.peak {
                        StationPeakBadge(
                            peak: peak,
                            accessibilityLabel: "Affluence en correspondance",
                            size: 24,
                            isInteractive: false
                        )
                    }
                }
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
            if isSelected {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        Color.accentColor.opacity(0.8),
                        lineWidth: 2.5
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var routeBadges: [JourneyRouteBadge] {
        journey.sections.compactMap { section in
            guard let route = section.route else { return nil }
            return JourneyRouteBadge(
                id: section.id,
                route: RouteBadge(
                    id: route.id,
                    shortName: route.shortName,
                    mode: route.mode,
                    colorHex: route.colorHex,
                    textColorHex: route.textColorHex
                )
            )
        }
    }

    private var maximumVisibleRouteBadges: Int {
        dynamicTypeSize.isAccessibilitySize ? 2 : 4
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
        if let peak = journey.peak {
            let station = peak.stationName.map { " — \($0)" } ?? ""
            value += ", Affluence en correspondance\(station), \(peak.label)"
        }
        if !journey.warnings.isEmpty { value += ", avertissement: \(journey.warnings.joined(separator: ", "))" }
        return value
    }

}

private struct JourneyRouteBadge: Identifiable {
    let id: String
    let route: RouteBadge
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
