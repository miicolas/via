import SwiftUI

/// One row of the journey timeline: its rail slice, its content and its time.
///
/// The same row serves the pre-trip detail and live guidance; only `state` and
/// `cursorFraction` differ between the two.
struct JourneyTimelineNodeRow: View {
    let node: JourneyTimelineNode
    let state: JourneyTimelineNodeState
    var cursorFraction: Double?
    var isCursorLive = false
    var isHighlighted = false
    @Binding var isExpanded: Bool
    /// `nil` when rows are not selectable, as in guidance where the map already
    /// follows the current section.
    var onSelect: (() -> Void)?

    private static let timeColumnWidth: CGFloat = 54

    var body: some View {
        if case .ride(let intermediate) = node.kind {
            VStack(spacing: 0) {
                rideRow(intermediate)
                if isExpanded {
                    JourneyStopListView(stops: intermediate, rail: node.railBelow, state: state)
                }
            }
        } else if let onSelect {
            Button(action: onSelect) {
                rowBody
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(state == .current ? [.isSelected] : [])
        } else {
            rowBody
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    // MARK: - Generic row

    private var rowBody: some View {
        HStack(alignment: .top, spacing: 0) {
            rail
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 8)
            trailing
        }
        .padding(.vertical, verticalPadding)
        .opacity(state == .done ? 0.45 : 1)
        .contentShape(.rect)
        .animation(.smooth(duration: 0.35), value: state)
    }

    private var rail: some View {
        JourneyTimelineRail(
            above: node.railAbove,
            below: node.railBelow,
            bead: node.bead,
            state: state,
            cursorFraction: cursorFraction,
            cursorSymbol: cursorSymbol,
            isCursorLive: isCursorLive
        )
    }

    private var verticalPadding: CGFloat {
        switch node.kind {
        case .board, .alight, .origin, .destination: 6
        default: 8
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch node.kind {
        case .origin(let name):
            place(name, caption: "Départ")
        case .destination(let name):
            place(name, caption: "Arrivée", symbol: "flag.checkered")
        case .board(let stop, let route, let direction, let platform):
            VStack(alignment: .leading, spacing: 8) {
                JourneyLegHeaderView(
                    route: route,
                    direction: direction,
                    platform: platform,
                    durationSeconds: node.durationSeconds,
                    isDimmed: state == .done
                )
                Text(stop.name)
                    .font(.headline)
            }
        case .alight(let stop):
            VStack(alignment: .leading, spacing: 3) {
                Text(stop.name)
                    .font(.headline)
                Label("Descendre ici", systemImage: "arrow.down.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        case .walk(let destination):
            movement("Marcher jusqu'à \(destination)", symbol: "figure.walk")
        case .wait(let place):
            movement("Attendre à \(place)", symbol: "clock")
        case .transfer(let destination):
            movement("Correspondance vers \(destination)", symbol: "arrow.triangle.turn.up.right.diamond")
        case .ride:
            EmptyView()
        }
    }

    private func place(_ name: String, caption: String, symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
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
                .font(.headline)
        }
    }

    private func movement(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }

    // MARK: - Trailing column

    @ViewBuilder
    private var trailing: some View {
        switch node.kind {
        case .origin, .destination, .board, .alight:
            Text(JourneyFormatting.time(node.startsAt))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(width: Self.timeColumnWidth, alignment: .trailing)
        case .walk, .wait, .transfer, .ride:
            Text(JourneyFormatting.duration(node.durationSeconds))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: Self.timeColumnWidth, alignment: .trailing)
        }
    }

    // MARK: - Ride row

    private func rideRow(_ intermediate: [JourneyStop]) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) { isExpanded.toggle() }
        } label: {
            HStack(alignment: .top, spacing: 0) {
                rail
                HStack(spacing: 4) {
                    Text(stopCountTitle(intermediate.count))
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(JourneyFormatting.duration(node.durationSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: Self.timeColumnWidth, alignment: .trailing)
            }
            .frame(minHeight: 44)
            .opacity(state == .done ? 0.45 : 1)
            .contentShape(.rect)
            .animation(.smooth(duration: 0.35), value: state)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(stopCountTitle(intermediate.count))
        .accessibilityHint(isExpanded ? "Masquer les arrêts" : "Afficher les arrêts et leurs horaires")
        .accessibilityAddTraits(isHighlighted ? [.isSelected] : [])
    }

    private func stopCountTitle(_ count: Int) -> String {
        count == 1 ? "1 arrêt" : "\(count) arrêts"
    }

    // MARK: - Cursor and accessibility

    private var cursorSymbol: String {
        switch node.kind {
        case .walk, .transfer: "figure.walk"
        case .wait: "clock.fill"
        case .ride: node.mode?.chipSystemImage ?? "tram.fill"
        default: "location.fill"
        }
    }

    private var accessibilityLabel: String {
        let time = JourneyFormatting.time(node.startsAt)
        let base: String = switch node.kind {
        case .origin(let name): "Départ de \(name) à \(time)"
        case .destination(let name): "Arrivée à \(name) à \(time)"
        case .board(let stop, let route, let direction, _):
            [
                "Monter à \(stop.name) à \(time)",
                route.map { "\($0.mode.displayName) \($0.shortName)" },
                direction.map { "direction \($0)" },
            ].compactMap(\.self).joined(separator: ", ")
        case .alight(let stop): "Descendre à \(stop.name) à \(time)"
        case .walk(let destination):
            "Marcher \(JourneyFormatting.duration(node.durationSeconds)) jusqu'à \(destination)"
        case .wait(let place):
            "Attendre \(JourneyFormatting.duration(node.durationSeconds)) à \(place)"
        case .transfer(let destination):
            "Correspondance de \(JourneyFormatting.duration(node.durationSeconds)) vers \(destination)"
        case .ride(let intermediate): stopCountTitle(intermediate.count)
        }

        return switch state {
        case .done: "\(base). Déjà parcouru."
        case .current: "\(base). Étape en cours."
        case .upcoming: base
        }
    }
}
