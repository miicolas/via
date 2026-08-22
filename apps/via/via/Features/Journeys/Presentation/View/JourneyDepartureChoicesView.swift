import SwiftUI

/// The selected service and the next compatible one, shared by planning and
/// live guidance. It never owns network work; it only reports intent upward.
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
        ForEach(group.choices.prefix(2)) { choice in
            Button {
                onSelect(choice)
            } label: {
                HStack(spacing: 7) {
                    if let route {
                        LineBadgeView(route: route.badge, size: 22)
                    }

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
            .accessibilityHint(choice.isSelected ? "Passage retenu" : "Décale la suite du trajet")
        }
    }

    @ViewBuilder
    private func context(for group: JourneyDepartureChoiceGroup) -> some View {
        HStack(spacing: 5) {
            Image(systemName: group.source.systemImage)
            Text(group.source.title)
            if group.availability == .unavailable {
                Text("· Aucun passage suivant")
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
        return "Actualisé \(date.formatted(.relative(presentation: .named)))"
    }
}
