import SwiftUI

/// One textual event beside the rail. Vehicle guidance is owned by the parent
/// section, leaving this row responsible only for a place, instruction or stop.
struct JourneyTimelineNodeRow: View {
    let node: JourneyTimelineNode
    let state: JourneyTimelineNodeState
    var cursorFraction: Double?
    var isCursorLive = false
    @Binding var isExpanded: Bool
    var departureChoicesGroup: JourneyDepartureChoiceGroup?
    var isDepartureChoicesLoading = false
    var isSelectingDeparture = false
    var departureChoicesError: String?
    var canSelectDepartures = false
    var onSelectDeparture: ((JourneyDepartureChoice) -> Void)?
    var onRetryDepartures: (() -> Void)?

    private static let timeColumnWidth: CGFloat = 68

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if case .ride(let intermediate) = node.kind {
            VStack(spacing: 0) {
                if hiddenStopCount(in: intermediate) > 0 {
                    rideRow(hiddenStopCount: hiddenStopCount(in: intermediate))
                }

                JourneyStopListView(
                    stops: intermediate,
                    rail: node.railBelow,
                    state: state,
                    isExpanded: isExpanded
                )
            }
        } else if case .board(_, let route, _, _, _) = node.kind,
                  showsDepartureChoices {
            VStack(alignment: .leading, spacing: 0) {
                row

                JourneyDepartureChoicesView(
                    route: route,
                    group: departureChoicesGroup,
                    isLoading: isDepartureChoicesLoading,
                    isSelecting: isSelectingDeparture,
                    errorMessage: departureChoicesError,
                    canSelect: canSelectDepartures,
                    onSelect: { onSelectDeparture?($0) },
                    onRetry: { onRetryDepartures?() }
                )
                .padding(.leading, JourneyTimelineRail.width + 10)
                .padding(.trailing, 8)
                .padding(.bottom, 12)
            }
        } else {
            row
        }
    }

    private var row: some View {
        rowBody
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
    }

    private var showsDepartureChoices: Bool {
        departureChoicesGroup != nil
            || isDepartureChoicesLoading
            || departureChoicesError != nil
    }

    private var rowBody: some View {
        HStack(alignment: .top, spacing: 0) {
            rail
                .frame(maxHeight: .infinity)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 10)
                .padding(.vertical, verticalPadding)
                .opacity(contentOpacity)

            trailing
                .padding(.vertical, verticalPadding)
                .opacity(contentOpacity)
        }
        .frame(minHeight: minimumHeight)
        .contentShape(.rect)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: state)
    }

    private var rail: some View {
        JourneyTimelineRail(
            above: node.railAbove,
            below: node.railBelow,
            bead: node.bead,
            state: state,
            cursorFraction: cursorFraction,
            isCursorLive: isCursorLive
        )
    }

    private var verticalPadding: CGFloat {
        switch node.kind {
        case .board, .alight: 10
        case .origin, .destination: 12
        case .walk, .bike, .wait, .transfer, .ride: 14
        }
    }

    private var minimumHeight: CGFloat {
        switch node.kind {
        case .board, .alight: 76
        case .origin, .destination: 62
        case .walk, .bike, .wait, .transfer, .ride: 66
        }
    }

    @ViewBuilder
    private var content: some View {
        switch node.kind {
        case .origin(let name):
            place(name, caption: "Départ")
        case .destination(let name):
            place(name, caption: "Arrivée", symbol: "flag.checkered")
        case .board(let stop, let route, let direction, let platform, _):
            VStack(alignment: .leading, spacing: 5) {
                Text(stop.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(routeTint(route))
                    .lineLimit(3)

                HStack(spacing: 8) {
                    if let direction, !direction.isEmpty {
                        Text("→ \(direction)")
                            .lineLimit(2)
                    }

                    if let platform, !platform.isEmpty {
                        Label(platform, systemImage: "rectangle.split.3x1")
                    }
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
            }
        case .alight(let stop, let exit):
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Image(systemName: "arrow.down.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(stop.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(node.railAbove.lineTint ?? .primary)
                        .lineLimit(3)
                }

                if let exit {
                    JourneyExitView(exit: exit, isDimmed: state == .done)
                }
            }
        case .walk:
            movement(
                JourneySectionNarration.movementSentence(for: node.kind, voice: .timeline),
                symbol: "figure.walk"
            )
        case .bike:
            movement(
                JourneySectionNarration.movementSentence(for: node.kind, voice: .timeline),
                symbol: "bicycle"
            )
        case .wait:
            movement(
                JourneySectionNarration.movementSentence(for: node.kind, voice: .timeline),
                symbol: "clock"
            )
        case .transfer:
            movement(
                JourneySectionNarration.movementSentence(for: node.kind, voice: .timeline),
                symbol: "arrow.triangle.turn.up.right.diamond"
            )
        case .ride:
            EmptyView()
        }
    }

    private func place(_ name: String, caption: String, symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(caption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(name)
                .font(.title3.weight(.semibold))
                .lineLimit(3)
        }
    }

    private func movement(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.body.weight(.medium))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            .lineLimit(3)
    }

    @ViewBuilder
    private var trailing: some View {
        switch node.kind {
        case .origin, .destination, .board, .alight:
            Text(JourneyFormatting.time(node.startsAt))
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .animation(reduceMotion ? nil : .default, value: node.startsAt)
                .frame(width: Self.timeColumnWidth, alignment: .trailing)
        case .walk, .bike, .wait, .transfer:
            VStack(alignment: .trailing, spacing: 4) {
                Text(JourneyFormatting.time(node.endsAt))
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)

                Text(JourneyFormatting.duration(node.durationSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .frame(width: Self.timeColumnWidth, alignment: .trailing)
        case .ride:
            EmptyView()
        }
    }

    private func rideRow(hiddenStopCount: Int) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 0) {
                rail
                    .frame(maxHeight: .infinity)

                HStack(spacing: 7) {
                    Text(stopCountTitle(hiddenStopCount))
                        .font(.body.weight(.semibold))

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(node.railBelow.lineTint ?? .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .opacity(contentOpacity)

                Text(JourneyFormatting.duration(node.durationSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: Self.timeColumnWidth, alignment: .trailing)
                    .padding(.vertical, 14)
                    .opacity(contentOpacity)
            }
            .frame(minHeight: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(stopCountTitle(hiddenStopCount))
        .accessibilityHint(isExpanded ? "Masque les stations" : "Affiche toutes les stations")
    }

    private func hiddenStopCount(in intermediate: [JourneyStop]) -> Int {
        max(0, intermediate.count - 1)
    }

    private func stopCountTitle(_ count: Int) -> String {
        count == 1 ? "1 autre arrêt" : "\(count) autres arrêts"
    }

    private func routeTint(_ route: JourneyRoute?) -> Color {
        guard let route else { return .primary }
        return Color(transitHex: route.colorHex, fallback: .accentColor)
    }

    private var contentOpacity: Double {
        state == .done ? 0.42 : 1
    }

    private var accessibilityLabel: String {
        let time = JourneyFormatting.time(node.startsAt)
        let base: String = switch node.kind {
        case .origin(let name):
            "Départ de \(name) à \(time)"
        case .destination(let name):
            "Arrivée à \(name) à \(time)"
        case .board(let stop, let route, let direction, let platform, let position):
            [
                "Monter à \(stop.name) à \(time)",
                route.map { "\($0.mode.displayName) \($0.shortName)" },
                direction.map { "direction \($0)" },
                platform.map { "quai \($0)" },
                position.map(JourneyFormatting.boardingPositionAccessibilityLabel),
            ].compactMap(\.self).joined(separator: ", ")
        case .alight(let stop, let exit):
            [
                "Descendre à \(stop.name) à \(time)",
                exit.map {
                    JourneyFormatting.exitAccessibilityLabel(
                        name: $0.name,
                        number: $0.number,
                        walkingMeters: $0.walkingMeters
                    )
                },
            ].compactMap(\.self).joined(separator: ". ")
        case .walk:
            JourneySectionNarration.accessibilitySentence(
                for: node.kind,
                duration: JourneyFormatting.duration(node.durationSeconds)
            )
        case .bike:
            JourneySectionNarration.accessibilitySentence(
                for: node.kind,
                duration: JourneyFormatting.duration(node.durationSeconds)
            )
        case .wait:
            JourneySectionNarration.accessibilitySentence(
                for: node.kind,
                duration: JourneyFormatting.duration(node.durationSeconds)
            )
        case .transfer:
            JourneySectionNarration.accessibilitySentence(
                for: node.kind,
                duration: JourneyFormatting.duration(node.durationSeconds)
            )
        case .ride(let intermediate):
            stopCountTitle(hiddenStopCount(in: intermediate))
        }

        return switch state {
        case .done: "\(base). Déjà parcouru."
        case .current: "\(base). Étape en cours."
        case .upcoming: base
        }
    }
}
