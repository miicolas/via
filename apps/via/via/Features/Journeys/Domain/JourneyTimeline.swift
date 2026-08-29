import Foundation

/// Style of the rail drawn between two consecutive timeline nodes.
///
/// Shared with the Lignes tab: a line plan is the same rail read without a
/// traveller on it, which is why the interrupted case lives here rather than
/// in a vocabulary of its own.
enum JourneyTimelineRailStyle: Sendable, Hashable {
    /// A ridden leg: continuous stroke in the line colour.
    case line(colorHex: String?)
    /// A stretch no train runs over right now: the same band, broken into
    /// dashes and tinted by the disruption instead of by the line.
    case cut(LineCondition)
    /// Walking, transferring or waiting: dotted neutral stroke.
    case pedestrian
    /// No rail at all — the two nodes describe the same point in space.
    case none
}

/// Marker drawn on the rail for a node.
enum JourneyTimelineBead: Sendable, Hashable {
    /// Start and end of the whole journey.
    case terminus
    /// Boarding and alighting stops.
    case major
    /// Intermediate stops, listed when a leg is expanded.
    case minor
    /// Nodes that only describe a movement, not a place.
    case none
}

/// What sits inside the white station hole punched through the rail.
///
/// A journey never carries one — a planned trip is by construction one the
/// trains run. A line plan does: the hole is where the Lignes tab says a
/// station is in trouble, instead of decorating its name.
enum JourneyTimelineBeadMark: Sendable, Hashable {
    /// Trains call normally: the plain white hole of a platform display.
    case open
    /// The station sits inside a disruption but trains still call: the hole
    /// carries an exclamation mark in the disruption's colour.
    case warned(LineCondition)
    /// No train calls here at all: the hole carries a cross.
    case closed(LineCondition)

    /// The disruption behind the mark; nil while the station runs normally.
    var condition: LineCondition? {
        switch self {
        case .open: nil
        case .warned(let condition), .closed(let condition): condition
        }
    }
}

/// One row of the journey timeline.
///
/// The description resolves every boundary time, so a row never has to fall back
/// to `JourneySection.departureAt` / `arrivalAt` — the planners frequently omit
/// both, which is why the previous timeline showed no times at all on walking,
/// waiting and transfer rows.
struct JourneyTimelineNode: Identifiable, Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case origin(name: String)
        case walk(destination: String)
        case bike(destination: String)
        case wait(place: String)
        case transfer(destination: String)
        case board(
            stop: JourneyStop,
            route: JourneyRoute?,
            direction: String?,
            platform: String?,
            position: JourneyBoardingPosition?
        )
        case ride(intermediate: [JourneyStop])
        case alight(stop: JourneyStop, exit: JourneyExit?)
        case destination(name: String)
    }

    let id: String
    let sectionID: String
    let sectionIndex: Int
    let kind: Kind
    let startsAt: Date
    let endsAt: Date
    let railAbove: JourneyTimelineRailStyle
    let railBelow: JourneyTimelineRailStyle
    let bead: JourneyTimelineBead
    /// Mode of the leg this node belongs to, for callers that glyph it.
    let mode: TransitMode?

    var durationSeconds: Int {
        Int(max(0, endsAt.timeIntervalSince(startsAt)).rounded())
    }

    /// Zero-length planner scaffolding is not something the traveller does, so
    /// it earns no row and no map stop.
    var isTravellerInstruction: Bool {
        switch kind {
        case .walk, .bike, .wait, .transfer: durationSeconds > 0
        case .origin, .board, .ride, .alight, .destination: true
        }
    }

    /// Colour of the leg this node belongs to, when it is a ridden one.
    var lineColorHex: String? {
        switch railBelow {
        case .line(let colorHex): return colorHex
        default: break
        }
        switch railAbove {
        case .line(let colorHex): return colorHex
        default: return nil
        }
    }
}

/// Pure description of a `Journey` into the rows the timeline renders.
///
/// Built on top of `ActiveJourneyRules.schedule(for:)`, which already fills the
/// gaps left by the planners by walking a clock from `journey.departureAt`.
enum JourneyTimeline {
    static func nodes(for journey: Journey) -> [JourneyTimelineNode] {
        let schedule = ActiveJourneyRules.schedule(for: journey)
        guard let first = schedule.first, let last = schedule.last else { return [] }

        var drafts: [Draft] = [
            Draft(
                id: "origin",
                sectionID: first.section.id,
                sectionIndex: 0,
                kind: .origin(name: first.section.from.name),
                startsAt: journey.departureAt,
                endsAt: journey.departureAt,
                rail: railStyle(for: first.section),
                bead: .terminus,
                mode: first.section.route?.mode
            )
        ]

        for (index, entry) in schedule.enumerated() {
            drafts.append(contentsOf: sectionDrafts(for: entry, index: index))
        }

        drafts.append(
            Draft(
                id: "destination",
                sectionID: last.section.id,
                sectionIndex: schedule.count - 1,
                kind: .destination(name: last.section.to.name),
                startsAt: journey.arrivalAt,
                endsAt: journey.arrivalAt,
                rail: railStyle(for: last.section),
                bead: .terminus,
                mode: last.section.route?.mode
            )
        )

        return link(drafts)
    }

    // MARK: - Section description

    private static func sectionDrafts(for entry: JourneySectionSchedule, index: Int) -> [Draft] {
        let section = entry.section
        let rail = railStyle(for: section)

        switch section.kind {
        case .bike:
            return [
                Draft(
                    id: "\(section.id):bike",
                    sectionID: section.id,
                    sectionIndex: index,
                    kind: .bike(destination: section.to.name),
                    startsAt: entry.startsAt,
                    endsAt: entry.endsAt,
                    rail: rail,
                    bead: .none,
                    mode: section.route?.mode
                )
            ]
        case .walk:
            return [
                Draft(
                    id: "\(section.id):walk",
                    sectionID: section.id,
                    sectionIndex: index,
                    kind: .walk(destination: section.to.name),
                    startsAt: entry.startsAt,
                    endsAt: entry.endsAt,
                    rail: rail,
                    bead: .none,
                    mode: section.route?.mode
                )
            ]
        case .wait:
            return [
                Draft(
                    id: "\(section.id):wait",
                    sectionID: section.id,
                    sectionIndex: index,
                    kind: .wait(place: section.from.name),
                    startsAt: entry.startsAt,
                    endsAt: entry.endsAt,
                    rail: rail,
                    bead: .none,
                    mode: section.route?.mode
                )
            ]
        case .transfer:
            return [
                Draft(
                    id: "\(section.id):transfer",
                    sectionID: section.id,
                    sectionIndex: index,
                    kind: .transfer(destination: section.to.name),
                    startsAt: entry.startsAt,
                    endsAt: entry.endsAt,
                    rail: rail,
                    bead: .none,
                    mode: section.route?.mode
                )
            ]
        case .transit:
            return transitDrafts(for: entry, index: index, rail: rail)
        }
    }

    private static func transitDrafts(
        for entry: JourneySectionSchedule,
        index: Int,
        rail: JourneyTimelineRailStyle
    ) -> [Draft] {
        let section = entry.section
        let boardingStop = section.stops.first ?? synthesizedStop(
            id: "\(section.id):from",
            place: section.from,
            arrivalAt: nil,
            departureAt: entry.startsAt
        )
        let alightingStop = section.stops.count > 1
            ? section.stops[section.stops.count - 1]
            : synthesizedStop(
                id: "\(section.id):to",
                place: section.to,
                arrivalAt: entry.endsAt,
                departureAt: nil
            )
        let intermediate = section.stops.count > 2
            ? Array(section.stops.dropFirst().dropLast())
            : []

        let boardingTime = boardingStop.departureAt ?? boardingStop.arrivalAt ?? entry.startsAt
        let alightingTime = alightingStop.arrivalAt ?? alightingStop.departureAt ?? entry.endsAt

        var drafts = [
            Draft(
                id: "\(section.id):board",
                sectionID: section.id,
                sectionIndex: index,
                kind: .board(
                    stop: boardingStop,
                    route: section.route,
                    direction: section.direction,
                    platform: section.platform,
                    position: section.boardingPosition
                ),
                startsAt: boardingTime,
                endsAt: boardingTime,
                rail: rail,
                bead: .major,
                mode: section.route?.mode
            )
        ]

        if !intermediate.isEmpty {
            drafts.append(
                Draft(
                    id: "\(section.id):ride",
                    sectionID: section.id,
                    sectionIndex: index,
                    kind: .ride(intermediate: intermediate),
                    startsAt: boardingTime,
                    endsAt: alightingTime,
                    rail: rail,
                    bead: .none,
                    mode: section.route?.mode
                )
            )
        }

        drafts.append(
            Draft(
                id: "\(section.id):alight",
                sectionID: section.id,
                sectionIndex: index,
                kind: .alight(stop: alightingStop, exit: section.exit),
                startsAt: alightingTime,
                endsAt: alightingTime,
                rail: rail,
                bead: .major,
                mode: section.route?.mode
            )
        )

        return drafts
    }

    private static func synthesizedStop(
        id: String,
        place: JourneyPlace,
        arrivalAt: Date?,
        departureAt: Date?
    ) -> JourneyStop {
        JourneyStop(
            id: id,
            name: place.name,
            coordinate: place.coordinate,
            arrivalAt: arrivalAt,
            departureAt: departureAt
        )
    }

    private static func railStyle(for section: JourneySection) -> JourneyTimelineRailStyle {
        section.kind == .transit ? .line(colorHex: section.route?.colorHex) : .pedestrian
    }

    // MARK: - Rail linking

    private struct Draft {
        let id: String
        let sectionID: String
        let sectionIndex: Int
        let kind: JourneyTimelineNode.Kind
        let startsAt: Date
        let endsAt: Date
        let rail: JourneyTimelineRailStyle
        let bead: JourneyTimelineBead
        let mode: TransitMode?
    }

    private static func link(_ drafts: [Draft]) -> [JourneyTimelineNode] {
        let rails = (0..<max(0, drafts.count - 1)).map { index in
            rail(between: drafts[index], and: drafts[index + 1])
        }

        return drafts.enumerated().map { index, draft in
            JourneyTimelineNode(
                id: draft.id,
                sectionID: draft.sectionID,
                sectionIndex: draft.sectionIndex,
                kind: draft.kind,
                startsAt: draft.startsAt,
                endsAt: draft.endsAt,
                railAbove: index == 0 ? .none : rails[index - 1],
                railBelow: index == rails.count ? .none : rails[index],
                bead: draft.bead,
                mode: draft.mode
            )
        }
    }

    /// The gap between two nodes belongs to the leg being travelled across it.
    /// After an alighting the leg is over, so the gap takes the next node's leg.
    private static func rail(between lhs: Draft, and rhs: Draft) -> JourneyTimelineRailStyle {
        if describesSamePlace(lhs, rhs) { return .none }

        switch lhs.kind {
        case .alight: return rhs.rail
        default: return lhs.rail
        }
    }

    /// A journey that starts by boarding, or ends by alighting, produces two
    /// nodes for one physical place. Drawing a rail between them would invent a
    /// movement that never happens.
    private static func describesSamePlace(_ lhs: Draft, _ rhs: Draft) -> Bool {
        switch (lhs.kind, rhs.kind) {
        case (.origin, .board), (.alight, .destination): return true
        default: return false
        }
    }
}

/// How far along the journey a node sits, relative to the current section.
enum JourneyTimelineNodeState: Sendable, Hashable {
    /// Behind the traveller — dimmed on the rail and on the map.
    case done
    /// Where the traveller is right now.
    case current
    /// Still ahead — rendered at full strength.
    case upcoming
}

extension JourneyTimeline {
    /// Without a current section every node reads as upcoming, which is exactly
    /// what the pre-trip detail wants.
    static func state(
        of node: JourneyTimelineNode,
        currentSectionIndex: Int?
    ) -> JourneyTimelineNodeState {
        guard let currentSectionIndex else { return .upcoming }
        if node.sectionIndex < currentSectionIndex { return .done }
        if node.sectionIndex > currentSectionIndex { return .upcoming }
        return .current
    }
}
