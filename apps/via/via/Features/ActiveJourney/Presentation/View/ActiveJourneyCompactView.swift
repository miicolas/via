import SwiftUI

/// The whole collapsed sheet while a journey runs: what to do now, when you
/// arrive, and what comes next.
///
/// It replaces the tab bar rather than sitting above it. At that height a tab
/// bar plus an accessory left one squeezed line for the guidance; giving the
/// journey the entire collapsed sheet buys four readable rows, and the tabs are
/// one drag away.
struct ActiveJourneyCompactView: View {
    let journey: Journey
    let headline: JourneyGuidanceHeadline
    let currentSectionIndex: Int?
    let action: () -> Void

    /// Beyond that the strip stops naming steps and counts them instead: the
    /// row has to stay one line on the narrowest phone.
    private static let maxRemainingSteps = 4

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                headlineRow
                remainderRow
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trajet en cours. \(headline.title)")
        .accessibilityHint("Ouvre le guidage du trajet")
    }

    private var headlineRow: some View {
        HStack(alignment: .center, spacing: 12) {
            leading

            VStack(alignment: .leading, spacing: 1) {
                Text(headline.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let detail = headline.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 0) {
                Text(JourneyFormatting.time(journey.arrivalAt))
                    .font(.title3.weight(.bold).monospacedDigit())
                Text("arrivée")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Arrivée prévue à \(JourneyFormatting.time(journey.arrivalAt))")
        }
    }

    /// What is left after the current step, so the collapsed sheet answers
    /// "and then?" without being opened.
    @ViewBuilder
    private var remainderRow: some View {
        let steps = remainingSteps

        HStack(spacing: 6) {
            if steps.isEmpty {
                Image(systemName: "flag.checkered")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Puis")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(steps.prefix(Self.maxRemainingSteps).enumerated()), id: \.offset) { index, step in
                    if index > 0 {
                        Image(systemName: "chevron.compact.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    stepGlyph(for: step)
                }

                if steps.count > Self.maxRemainingSteps {
                    Text("+\(steps.count - Self.maxRemainingSteps)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.compact.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(destinationName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(remainderAccessibilityLabel(steps: steps))
    }

    @ViewBuilder
    private func stepGlyph(for step: JourneySection) -> some View {
        if let route = step.route {
            LineBadgeView(route: route.badge, size: 18)
        } else {
            Image(systemName: step.kind.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
        }
    }

    @ViewBuilder
    private var leading: some View {
        if let route = headline.route {
            LineBadgeView(route: route.badge, size: 30)
        } else {
            Image(systemName: headline.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
        }
    }

    /// Waits belong to the step they precede, so they never earn a glyph of
    /// their own in a row this short.
    private var remainingSteps: [JourneySection] {
        let next = (currentSectionIndex ?? 0) + 1
        guard journey.sections.indices.contains(next) else { return [] }
        return journey.sections[next...].filter { $0.kind != .wait }
    }

    private var destinationName: String {
        journey.sections.last?.to.name ?? ""
    }

    private func remainderAccessibilityLabel(steps: [JourneySection]) -> String {
        guard !steps.isEmpty else { return "Dernière étape jusqu’à \(destinationName)" }
        let transits = steps.compactMap(\.route?.shortName)
        guard !transits.isEmpty else {
            return "\(steps.count) étapes restantes jusqu’à \(destinationName)"
        }
        return "Puis \(transits.joined(separator: ", ")) jusqu’à \(destinationName)"
    }
}

#Preview {
    let journey = Journey.mapPreviewMultipleTransfers
    let schedule = ActiveJourneyRules.schedule(for: journey)

    return ActiveJourneyCompactView(
        journey: journey,
        headline: JourneyGuidance.headline(
            journey: journey,
            schedule: schedule,
            sectionIndex: 1,
            at: journey.departureAt.addingTimeInterval(600),
            isPaused: false
        ),
        currentSectionIndex: 1,
        action: {}
    )
    .padding(.vertical, 14)
    .background(.background)
}
