import MapKit

struct JourneyMapSegment: Identifiable, Sendable, Hashable {
    let id: String
    let sectionIndex: Int
    let coordinates: [GeoCoordinate]
    let colorHex: String?
    let isPedestrian: Bool
    let isStationary: Bool
}

/// A place on the route worth marking: where to board, where to change, where
/// to get off.
struct JourneyMapStop: Identifiable, Sendable, Hashable {
    enum Kind: Sendable, Hashable { case origin, board, alight, destination }

    let id: String
    let name: String
    let coordinate: GeoCoordinate
    let kind: Kind
    let sectionIndex: Int
    let colorHex: String?
}

/// The recommended piece of station signage, projected separately from the
/// alighting stop because its coordinate is the actual street-level exit.
struct JourneyMapExit: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let number: Int?
    let coordinate: GeoCoordinate
    let walkingMeters: Int?
    let sectionIndex: Int

    var accessibilityLabel: String {
        JourneyFormatting.exitAccessibilityLabel(
            name: name,
            number: number,
            walkingMeters: walkingMeters
        )
    }
}

/// Map-ready description of a selected journey. The map never needs to learn
/// how journey sections, fallback geometry, or route colors are encoded.
struct JourneyMapPresentation: Identifiable, Sendable, Hashable {
    let id: JourneyID
    let segments: [JourneyMapSegment]
    let stops: [JourneyMapStop]
    let exits: [JourneyMapExit]

    init(journey: Journey) {
        id = journey.id
        segments = journey.sections.enumerated().map { index, section in
            JourneyMapSegment(
                id: section.id,
                sectionIndex: index,
                coordinates: journey.path(at: index),
                colorHex: section.route?.colorHex,
                isPedestrian: section.kind == .walk || section.kind == .bike || section.kind == .transfer,
                isStationary: section.kind == .wait
            )
        }
        stops = Self.stops(of: journey)
        exits = journey.sections.enumerated().compactMap { index, section in
            section.exit.map { exit in
                JourneyMapExit(
                    id: exit.id,
                    name: exit.name,
                    number: exit.number,
                    coordinate: exit.coordinate,
                    walkingMeters: exit.walkingMeters,
                    sectionIndex: index
                )
            }
        }
    }

    // MARK: - Framing

    var mapRect: MKMapRect? {
        mapRect(for: segments.flatMap(\.coordinates) + exits.map(\.coordinate))
    }

    func mapRect(for segmentID: String?) -> MKMapRect? {
        guard let segmentID,
              let segment = segments.first(where: { $0.id == segmentID }) else {
            return mapRect
        }
        let sectionExits = exits
            .filter { $0.sectionIndex == segment.sectionIndex }
            .map(\.coordinate)
        return mapRect(for: segment.coordinates + sectionExits)
    }

    private func mapRect(for coordinates: [GeoCoordinate]) -> MKMapRect? {
        let points = coordinates.map { MKMapPoint($0.clLocationCoordinate) }
        guard let first = points.first else { return nil }

        let rect = points.dropFirst().reduce(
            MKMapRect(x: first.x, y: first.y, width: 0, height: 0)
        ) { rect, point in
            rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        let minimumSize = 1_500.0
        let horizontalPadding = max(rect.size.width * 0.18, minimumSize)
        let verticalPadding = max(rect.size.height * 0.18, minimumSize)
        return rect.insetBy(dx: -horizontalPadding, dy: -verticalPadding)
    }

    // MARK: - Stops

    private static func stops(of journey: Journey) -> [JourneyMapStop] {
        let nodes = JourneyTimeline.nodes(for: journey)
        return nodes.compactMap { node in
            switch node.kind {
            case .origin(let name):
                return JourneyMapStop(
                    id: node.id,
                    name: name,
                    coordinate: journey.sections.first?.from.coordinate ?? .init(latitude: 0, longitude: 0),
                    kind: .origin,
                    sectionIndex: node.sectionIndex,
                    colorHex: nil
                )
            case .destination(let name):
                return JourneyMapStop(
                    id: node.id,
                    name: name,
                    coordinate: journey.sections.last?.to.coordinate ?? .init(latitude: 0, longitude: 0),
                    kind: .destination,
                    sectionIndex: node.sectionIndex,
                    colorHex: nil
                )
            case .board(let stop, let route, _, _, _):
                return JourneyMapStop(
                    id: node.id,
                    name: stop.name,
                    coordinate: stop.coordinate,
                    kind: .board,
                    sectionIndex: node.sectionIndex,
                    colorHex: route?.colorHex
                )
            case .alight(let stop, let exit):
                guard exit == nil else { return nil }
                return JourneyMapStop(
                    id: node.id,
                    name: stop.name,
                    coordinate: stop.coordinate,
                    kind: .alight,
                    sectionIndex: node.sectionIndex,
                    colorHex: node.lineColorHex
                )
            case .walk, .bike, .wait, .transfer, .ride:
                return nil
            }
        }
    }
}
