import SwiftUI

/// The three nearest passages of this leg, with the held one in the middle.
///
/// The traveller swipes the row one passage at a time. Keeping the previous
/// and next times visible makes the direction of the change obvious without
/// turning the control into a set of cards.
///
/// Shared by planning and live guidance; it never owns network work, it only
/// reports intent upward.
struct JourneyDepartureChoicesView: View {
    let route: JourneyRoute?
    let group: JourneyDepartureChoiceGroup?
    let isLoading: Bool
    /// A revision is in flight for this leg — the rail stays live while the
    /// selected time remains visible.
    var isSelecting = false
    let errorMessage: String?
    let canSelect: Bool
    let onSelect: (JourneyDepartureChoice) -> Void
    let onRetry: () -> Void

    @State private var focusedID: String?
    /// The last choice handed upward, so the end of a drag cannot submit it
    /// twice after the value has already been sent to the model.
    @State private var committedID: String?
    @State private var hapticTick = 0

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
        .onChange(of: focusedID) { _, id in
            guard let id else { return }
            commit(id)
        }
    }

    // MARK: - Three-time selector

    private var selector: some View {
        GeometryReader { proxy in
            let itemWidth = proxy.size.width / 3

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(choices) { choice in
                        departureChoice(choice, width: itemWidth)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedID, anchor: .center)
            .contentMargins(.horizontal, proxy.size.width / 3, for: .scrollContent)
            .scrollDisabled(choices.count < 2)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.13),
                        .init(color: .black, location: 0.87),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        .frame(height: 48)
        .sensoryFeedback(.selection, trigger: hapticTick)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Passages disponibles")
        .accessibilityValue(selectorAccessibilityValue)
        .accessibilityHint(
            choices.count > 1
                ? "Balayez vers la gauche ou la droite pour changer de passage"
                : ""
        )
        .accessibilityAdjustableAction { direction in
            adjustSelection(direction)
        }
    }

    private func departureChoice(
        _ choice: JourneyDepartureChoice,
        width: CGFloat
    ) -> some View {
        departureTime(choice)
            .frame(width: width)
            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                content
                    .scaleEffect(phase.isIdentity ? 1 : 0.82)
                    .opacity(phase.isIdentity ? 1 : 0.62)
            }
            .id(choice.id)
    }

    private func departureTime(_ choice: JourneyDepartureChoice) -> some View {
        Text(JourneyFormatting.time(choice.displayAt))
            .font(.title3.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
            .contentTransition(reduceMotion ? .identity : .numericText())
            .frame(maxWidth: .infinity, minHeight: 44)
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

    /// Hands the settled time upward once. A cancelled service is shown but
    /// never chosen, and the held one needs no revision.
    private func commit(_ id: String) {
        guard canSelect, id != committedID else { return }
        guard let choice = choices.first(where: { $0.id == id }) else { return }
        guard !choice.isSelected, choice.status != .cancelled else { return }
        committedID = id
        hapticTick += 1
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

    private var selectorAccessibilityValue: String {
        guard let choice = focusedChoice else { return position }
        var parts = [accessibilityLabel(choice), position]
        if isSelecting {
            parts.append("Mise à jour en cours")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
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
        HStack(spacing: 16) {
            Skeleton(.roundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity, minHeight: 20)
            Skeleton(.roundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity, minHeight: 26)
            Skeleton(.roundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity, minHeight: 20)
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
