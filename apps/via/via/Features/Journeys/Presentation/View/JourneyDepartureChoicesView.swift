import SwiftUI

/// The service held, with the compatible one before it and the one after,
/// chronologically. Choosing either re-centres the row on that departure, so a
/// traveller steps forward or back one passage at a time for as long as the
/// line runs. Shared by planning and live guidance; it never owns network work,
/// it only reports intent upward.
struct JourneyDepartureChoicesView: View {
    let route: JourneyRoute?
    let group: JourneyDepartureChoiceGroup?
    let isLoading: Bool
    let errorMessage: String?
    let canSelect: Bool
    let onSelect: (JourneyDepartureChoice) -> Void
    let onRetry: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonGate(isLoading: isLoading && group == nil) {
                skeleton
            } content: {
                if let group, !group.choices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        choices(group)
                        context(for: group)
                    }
                }
            }

            if let errorMessage {
                error(errorMessage)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: group)
    }

    private func choices(_ group: JourneyDepartureChoiceGroup) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                choiceButtons(group)
            }
            VStack(spacing: 8) {
                choiceButtons(group)
            }
        }
    }

    @ViewBuilder
    private func choiceButtons(_ group: JourneyDepartureChoiceGroup) -> some View {
        ForEach(group.choices) { choice in
            Button {
                onSelect(choice)
            } label: {
                HStack(spacing: 7) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Image(systemName: choice.source.systemImage)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(JourneyFormatting.time(choice.displayAt))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            if showsScheduledTime(choice) {
                                Text(JourneyFormatting.time(choice.scheduledAt))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .strikethrough()
                            }
                        }
                        if let status = statusLabel(choice) {
                            Text(status.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(status.color)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: choice.isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(
                            choice.isSelected ? Color.accentColor : Color.secondary.opacity(0.55)
                        )
                        .contentTransition(
                            reduceMotion
                                ? .identity
                                : .symbolEffect(
                                    .replace.magic(fallback: .offUp.byLayer),
                                    options: .nonRepeating
                                )
                        )
                        .animation(reduceMotion ? nil : .default, value: choice.isSelected)
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .background(
                    choice.isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            choice.isSelected ? Color.accentColor : Color.secondary.opacity(0.16),
                            lineWidth: choice.isSelected ? 1.5 : 1
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(choice.isSelected || choice.status == .cancelled || !canSelect || isLoading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(choice))
            .accessibilityAddTraits(choice.isSelected ? [.isSelected] : [])
            .accessibilityHint(hint(for: choice, in: group))
        }
    }

    @ViewBuilder
    private func context(for group: JourneyDepartureChoiceGroup) -> some View {
        HStack(spacing: 5) {
            Image(systemName: group.source.systemImage)
            Text(group.source.title)
            if group.availability == .unavailable {
                Text("· Aucun autre passage")
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityValue(freshnessLabel(group.fetchedAt))
    }

    private var skeleton: some View {
        HStack(spacing: 8) {
            Skeleton(.roundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity, minHeight: 52)
            Skeleton(.roundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .skeletonGroup(label: "Chargement des prochains passages")
    }

    private func error(_ message: String) -> some View {
        HStack(spacing: 8) {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            RetryButton(action: onRetry)
                .iconAction(size: .small)
                .accessibilityLabel("Réessayer les horaires directs")
        }
    }

    /// Which way this choice moves the journey, read off the chronological row
    /// rather than the clock: a delayed later service can still print an earlier
    /// time than the one held.
    private func hint(
        for choice: JourneyDepartureChoice,
        in group: JourneyDepartureChoiceGroup
    ) -> String {
        guard !choice.isSelected else { return "Passage retenu" }
        guard
            let index = group.choices.firstIndex(of: choice),
            let selected = group.choices.firstIndex(where: \.isSelected)
        else { return "Décale la suite du trajet" }
        return index < selected
            ? "Avance la suite du trajet au passage précédent"
            : "Décale la suite du trajet au passage suivant"
    }

    private func showsScheduledTime(_ choice: JourneyDepartureChoice) -> Bool {
        guard let expectedAt = choice.expectedAt else { return false }
        return abs(expectedAt.timeIntervalSince(choice.scheduledAt)) >= 30
    }

    private func statusLabel(_ choice: JourneyDepartureChoice) -> (title: String, color: Color)? {
        guard
            let title = choice.status.delayTitle(
                scheduledAt: choice.scheduledAt,
                expectedAt: choice.expectedAt
            )
        else { return nil }
        let role = departureTimeColorRole(
            status: choice.status,
            source: choice.source == .realtime ? .realtime : .theoretical
        )
        return (title, role.color)
    }

    private func accessibilityLabel(_ choice: JourneyDepartureChoice) -> String {
        var parts = [
            route.map { "\($0.mode.displayName) ligne \($0.shortName)" },
            "départ à \(JourneyFormatting.time(choice.displayAt))",
            choice.source.title,
            statusLabel(choice)?.title,
        ].compactMap(\.self)
        if showsScheduledTime(choice) {
            parts.append("prévu à \(JourneyFormatting.time(choice.scheduledAt))")
        }
        return parts.joined(separator: ", ")
    }

    private func freshnessLabel(_ date: Date?) -> String {
        guard let date else { return "Fraîcheur inconnue" }
        return "Actualisé \(RelativeTimeFormatting.spelled(date))"
    }
}
