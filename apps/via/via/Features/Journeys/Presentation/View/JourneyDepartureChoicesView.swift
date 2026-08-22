import SwiftUI

/// The passages of this leg, as one value the traveller scrubs through.
///
/// The gesture follows the reminder picker: the current passage stays legible
/// above a small, discrete track and dragging across it moves one passage at a
/// time. VoiceOver exposes the same control as an adjustable element.
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
    /// The last choice handed upward, so the end of a drag cannot submit it
    /// twice after the value has already been sent to the model.
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
                        selector
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

    // MARK: - Scrubber

    private var selector: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let choice = focusedChoice {
                card(choice)
            }

            scrubber
        }
    }

    private var scrubber: some View {
        GeometryReader { geometry in
            let inset: CGFloat = 12
            let usableWidth = max(1, geometry.size.width - inset * 2)
            let selectedIndex = focusedIndex ?? 0
            let progress = choices.count > 1
                ? CGFloat(selectedIndex) / CGFloat(choices.count - 1)
                : 0
            let thumbX = choices.count > 1
                ? inset + progress * usableWidth
                : geometry.size.width / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.16))
                    .frame(height: 5)

                Capsule()
                    .fill(Color.accentColor.opacity(0.72))
                    .frame(width: thumbX, height: 5)

                ForEach(Array(choices.enumerated()), id: \.element.id) { index, _ in
                    Circle()
                        .fill(
                            index == selectedIndex
                                ? Color.accentColor
                                : Color.secondary.opacity(0.42)
                        )
                        .frame(
                            width: index == selectedIndex ? 8 : 6,
                            height: index == selectedIndex ? 8 : 6
                        )
                        .offset(
                            x: trackX(
                                index: index,
                                count: choices.count,
                                inset: inset,
                                width: usableWidth
                            ) - (index == selectedIndex ? 4 : 3)
                        )
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Circle()
                            .strokeBorder(.background, lineWidth: 3)
                    }
                    .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
                    .offset(x: thumbX - 12)
                    .allowsHitTesting(false)
            }
            .frame(height: 28)
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateFocus(at: value.location.x, width: geometry.size.width, inset: inset)
                    }
                    .onEnded { _ in
                        commitFocused()
                    }
            )
        }
        .frame(height: 44)
        .sensoryFeedback(.selection, trigger: focusedID)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Passages disponibles")
        .accessibilityValue(position)
        .accessibilityHint(choices.count > 1 ? "Balayez vers la gauche ou la droite pour changer de passage" : "")
        .accessibilityAdjustableAction { direction in
            adjustSelection(direction)
        }
    }

    private func card(_ choice: JourneyDepartureChoice) -> some View {
        let isFocused = choice.id == activeID

        return Button {
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
                isFocused ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.accentColor : Color.secondary.opacity(0.16),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(choice.status == .cancelled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(choice))
        .accessibilityAddTraits(isFocused ? [.isSelected] : [])
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
        let isFocused = choice.id == activeID

        if isSelecting, isFocused, !choice.isSelected, choice.status != .cancelled {
            ProgressView()
                .controlSize(.small)
        } else {
            Image(systemName: isFocused ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(
                    isFocused ? Color.accentColor : Color.secondary.opacity(0.55)
                )
                .contentTransition(
                    reduceMotion
                        ? .identity
                        : .symbolEffect(
                            .replace.magic(fallback: .offUp.byLayer),
                            options: .nonRepeating
                        )
                )
                .animation(reduceMotion ? nil : .default, value: isFocused)
        }
    }

    // MARK: - Selection

    /// Where the selector sits right now, whatever the traveller last dragged past.
    private var focusedIndex: Int? {
        guard let id = activeID else { return nil }
        return choices.firstIndex { $0.id == id }
    }

    private func focus(_ id: String) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
            focusedID = id
        }
        commit(id)
    }

    private func updateFocus(at x: CGFloat, width: CGFloat, inset: CGFloat) {
        guard choices.count > 1, width > inset * 2 else { return }

        let progress = min(max((x - inset) / (width - inset * 2), 0), 1)
        let index = min(
            Int((progress * CGFloat(choices.count - 1)).rounded()),
            choices.count - 1
        )
        let id = choices[index].id
        guard id != focusedID else { return }

        withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
            focusedID = id
        }
    }

    private func trackX(index: Int, count: Int, inset: CGFloat, width: CGFloat) -> CGFloat {
        guard count > 1 else { return inset + width / 2 }
        return inset + CGFloat(index) / CGFloat(count - 1) * width
    }

    private func commitFocused() {
        guard let focusedID else { return }
        commit(focusedID)
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        guard let focusedIndex else { return }

        let targetIndex: Int
        switch direction {
        case .increment:
            targetIndex = min(focusedIndex + 1, choices.index(before: choices.endIndex))
        case .decrement:
            targetIndex = max(focusedIndex - 1, choices.startIndex)
        @unknown default:
            return
        }

        guard targetIndex != focusedIndex else { return }
        focus(choices[targetIndex].id)
    }

    /// Hands the settled card upward once. A cancelled service is shown but
    /// never chosen, and the held one needs no revision.
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
        guard !choices.isEmpty else {
            focusedID = nil
            return
        }
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

    private var activeID: String? {
        focusedID ?? selectedID
    }

    private var focusedChoice: JourneyDepartureChoice? {
        guard let focusedID else {
            return choices.first(where: \.isSelected) ?? choices.first
        }
        return choices.first(where: { $0.id == focusedID })
            ?? choices.first(where: \.isSelected)
            ?? choices.first
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
        guard choice.id != activeID else { return "Passage retenu" }
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
