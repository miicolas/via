import SwiftUI

/// The passages of this leg, as one rail the traveller slides along.
///
/// A row of buttons made stepping to another train a target to aim at; here the
/// gesture *is* the choice — drag left for the service after, right for the one
/// before, and whatever the rail settles on becomes the journey. The chevrons
/// exist for the same move without the gesture, and for VoiceOver.
///
/// Shared by planning and live guidance; it never owns network work, it only
/// reports intent upward.
struct JourneyDepartureChoicesView: View {
    let route: JourneyRoute?
    let group: JourneyDepartureChoiceGroup?
    let isLoading: Bool
    /// A revision is in flight for this leg — the rail stays live, the card
    /// simply says so.
    var isSelecting = false
    let errorMessage: String?
    let canSelect: Bool
    let onSelect: (JourneyDepartureChoice) -> Void
    let onRetry: () -> Void

    @State private var focusedID: String?
    /// The last choice handed upward, so settling twice on the same card — a
    /// programmatic scroll then its idle phase — asks for it once.
    @State private var committedID: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var choices: [JourneyDepartureChoice] { group?.choices ?? [] }

    private var selectedID: String? {
        choices.first(where: \.isSelected)?.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SkeletonGate(isLoading: isLoading && group == nil) {
                skeleton
            } content: {
                if let group, !group.choices.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        rail
                        context(for: group)
                    }
                }
            }

            if let errorMessage {
                error(errorMessage)
            }
        }
        .onAppear { focusedID = selectedID }
        .onChange(of: group) { _, _ in resynchronise() }
    }

    // MARK: - Rail

    private var rail: some View {
        HStack(spacing: 4) {
            stepper(-1, systemImage: "chevron.left", label: "Passage précédent")
            pager
            stepper(1, systemImage: "chevron.right", label: "Passage suivant")
        }
        .accessibilityElement(children: .contain)
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(choices) { choice in
                    card(choice)
                        // Just short of the full width, so the next service
                        // always shows an edge: the sliver is what tells the
                        // traveller the rail slides at all.
                        .containerRelativeFrame(.horizontal, count: 8, span: 7, spacing: 8)
                        .scrollTransition(
                            reduceMotion ? .identity : .interactive,
                            axis: .horizontal
                        ) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.45)
                                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                        }
                        .id(choice.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $focusedID)
        .scrollDisabled(choices.count <= 1)
        .onScrollPhaseChange { _, phase in
            guard phase == .idle else { return }
            commitFocused()
        }
        .sensoryFeedback(.selection, trigger: focusedID)
        .accessibilityHint(choices.count > 1 ? "Glissez pour changer de passage" : "")
    }

    private func card(_ choice: JourneyDepartureChoice) -> some View {
        Button {
            focus(choice.id)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    timing(choice)
                    clock(choice)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                indicator(for: choice)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 52)
            .background(
                choice.isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        choice.isSelected ? Color.accentColor : Color.secondary.opacity(0.16),
                        lineWidth: choice.isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(choice.status == .cancelled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(choice))
        .accessibilityAddTraits(choice.isSelected ? [.isSelected] : [])
        .accessibilityHint(hint(for: choice))
    }

    /// The wait, said exactly as the station board says it — same capsule, same
    /// minutes, same silence when the feed is only a schedule.
    @ViewBuilder
    private func timing(_ choice: JourneyDepartureChoice) -> some View {
        if let operational = operationalStatus(choice) {
            Label(operational.title, systemImage: operational.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(operational.color)
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(operational.color.opacity(0.10), in: Capsule())
        } else {
            DepartureCountdownView(
                departureAt: choice.displayAt,
                isLive: choice.source.isLive,
                role: departureTimeColorRole(
                    status: choice.status,
                    source: choice.source == .realtime ? .realtime : .theoretical
                ),
                prominence: .inline
            )
        }
    }

    /// The clock time under the countdown, and the schedule it slipped from
    /// when it did.
    private func clock(_ choice: JourneyDepartureChoice) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if showsScheduledTime(choice) {
                Text(JourneyFormatting.time(choice.scheduledAt))
                    .strikethrough()
                    .foregroundStyle(.secondary)
            }
            Text(JourneyFormatting.time(choice.displayAt))
                .foregroundStyle(showsScheduledTime(choice) ? statusColor(choice) : .secondary)
        }
        .font(.caption2.weight(.medium).monospacedDigit())
        .lineLimit(1)
    }

    @ViewBuilder
    private func indicator(for choice: JourneyDepartureChoice) -> some View {
        if isSelecting, choice.id == focusedID, !choice.isSelected {
            ProgressView()
                .controlSize(.small)
        } else {
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
    }

    private func stepper(_ offset: Int, systemImage: String, label: String) -> some View {
        Button(label, systemImage: systemImage) {
            step(offset)
        }
        .iconAction(size: .small)
        .disabled(neighbour(offset) == nil)
        .accessibilityLabel(label)
    }

    // MARK: - Stepping

    /// Where the rail sits right now, whatever the traveller last dragged past.
    private var focusedIndex: Int? {
        guard let id = focusedID ?? selectedID else { return nil }
        return choices.firstIndex { $0.id == id }
    }

    private func neighbour(_ offset: Int) -> JourneyDepartureChoice? {
        guard let focusedIndex else { return nil }
        let target = focusedIndex + offset
        guard choices.indices.contains(target) else { return nil }
        return choices[target]
    }

    private func step(_ offset: Int) {
        guard let choice = neighbour(offset) else { return }
        focus(choice.id)
    }

    private func focus(_ id: String) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
            focusedID = id
        }
        commit(id)
    }

    private func commitFocused() {
        guard let focusedID else { return }
        commit(focusedID)
    }

    /// Hands the settled card upward, once — a programmatic scroll and the idle
    /// phase that follows it are one gesture, not two. A cancelled service is
    /// shown but never chosen, and the held one needs no revision.
    private func commit(_ id: String) {
        guard canSelect, id != committedID else { return }
        guard let choice = choices.first(where: { $0.id == id }) else { return }
        guard !choice.isSelected, choice.status != .cancelled else { return }
        committedID = id
        onSelect(choice)
    }

    /// A new answer landed: follow it home unless the traveller has already
    /// dragged somewhere else the answer still knows about.
    private func resynchronise() {
        committedID = nil
        guard let selectedID else { return }
        if focusedID == nil || !choices.contains(where: { $0.id == focusedID }) {
            focusedID = selectedID
        }
    }

    // MARK: - Context

    @ViewBuilder
    private func context(for group: JourneyDepartureChoiceGroup) -> some View {
        HStack(spacing: 5) {
            if let systemImage = group.source.systemImage, let title = group.source.title {
                Image(systemName: systemImage)
                Text(title)
                Text("·")
            }
            Text(group.availability == .unavailable ? "Aucun autre passage" : position)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityValue(freshnessLabel(group.fetchedAt))
    }

    private var position: String {
        guard let focusedIndex else { return "" }
        return "\(focusedIndex + 1) sur \(choices.count)"
    }

    private var skeleton: some View {
        HStack(spacing: 8) {
            Skeleton(.roundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity, minHeight: 46)
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

    // MARK: - Wording

    /// Which way this choice moves the journey, read off the chronological rail
    /// rather than the clock: a delayed later service can still print an earlier
    /// time than the one held.
    private func hint(for choice: JourneyDepartureChoice) -> String {
        guard !choice.isSelected else { return "Passage retenu" }
        guard
            let index = choices.firstIndex(of: choice),
            let selected = choices.firstIndex(where: \.isSelected)
        else { return "Décale la suite du trajet" }
        return index < selected
            ? "Avance la suite du trajet à ce passage"
            : "Décale la suite du trajet à ce passage"
    }

    private func showsScheduledTime(_ choice: JourneyDepartureChoice) -> Bool {
        guard let expectedAt = choice.expectedAt else { return false }
        return abs(expectedAt.timeIntervalSince(choice.scheduledAt)) >= 30
    }

    /// A service that will not run says so instead of counting down to nothing.
    private func operationalStatus(
        _ choice: JourneyDepartureChoice
    ) -> (title: String, systemImage: String, color: Color)? {
        switch choice.status {
        case .cancelled: ("Annulé", "xmark.circle.fill", .red)
        case .missed: ("Non desservi", "slash.circle.fill", .orange)
        default: nil
        }
    }

    private func statusColor(_ choice: JourneyDepartureChoice) -> Color {
        departureTimeColorRole(
            status: choice.status,
            source: choice.source == .realtime ? .realtime : .theoretical
        ).color
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
            operationalStatus(choice)?.title
                ?? DepartureCountdownView.spokenWait(until: choice.displayAt),
            choice.source.title,
            statusLabel(choice)?.title,
        ].compactMap(\.self)
        if showsScheduledTime(choice) {
            parts.append("au lieu de \(JourneyFormatting.time(choice.scheduledAt))")
        }
        return parts.joined(separator: ", ")
    }

    private func freshnessLabel(_ date: Date?) -> String {
        guard let date else { return "Fraîcheur inconnue" }
        return "Actualisé \(RelativeTimeFormatting.spelled(date))"
    }
}

#Preview("Rail de passages") {
    let now = Date()
    let choices: [JourneyDepartureChoice] = [-2, -1, 0, 1, 2, 3].map { (step: Int) in
        let scheduledAt: Date = now.addingTimeInterval(Double(step) * 420)
        let expectedAt: Date? = step == 1 ? scheduledAt.addingTimeInterval(120) : nil
        let status: DepartureStatus = step == 1 ? .delayed : .scheduled
        let source: JourneyTimingSource = step == 1 ? .realtime : .theoretical
        return JourneyDepartureChoice(
            id: "departure:\(step)",
            scheduledAt: scheduledAt,
            expectedAt: expectedAt,
            status: status,
            source: source,
            isSelected: step == 0
        )
    }
    let group = JourneyDepartureChoiceGroup(
        sectionID: "ride",
        availability: .available,
        source: .realtime,
        fetchedAt: now,
        choices: choices
    )

    return ScrollView {
        JourneyDepartureChoicesView(
            route: nil,
            group: group,
            isLoading: false,
            errorMessage: nil,
            canSelect: true,
            onSelect: { _ in },
            onRetry: {}
        )
        .padding(.horizontal, 24)
    }
}
