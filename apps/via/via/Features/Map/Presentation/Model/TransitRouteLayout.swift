import Foundation

struct TransitMapViewport: Sendable, Hashable {
    let latitudeDelta: Double
    let longitudeDelta: Double
    let width: Double
    let height: Double
    let laneSpacingPoints: Double

    init(
        latitudeDelta: Double,
        longitudeDelta: Double,
        width: Double,
        height: Double,
        laneSpacingPoints: Double = 6
    ) {
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
        self.width = width
        self.height = height
        self.laneSpacingPoints = laneSpacingPoints
    }
}

struct TransitRouteLayout: Sendable {
    private static let metersPerLatitudeDegree = 111_320.0
    private static let sharedCorridorToleranceMeters = 40.0
    private static let minimumSharedCorridorMeters = 80.0
    private static let minimumParallelDotProduct = cos(18.0 * .pi / 180.0)
    private let metersPerLongitudeDegree: Double
    private let routes: [LayoutRoute]

    init(routes: [NetworkRoute]) {
        let coordinates = routes.flatMap { route in
            route.segments.flatMap(\.coordinates)
        }
        let referenceLatitude = coordinates.isEmpty
            ? 0
            : coordinates.reduce(0) { $0 + $1.latitude } / Double(coordinates.count)
        let longitudeScale = Self.metersPerLatitudeDegree * cos(referenceLatitude * .pi / 180)
        metersPerLongitudeDegree = max(longitudeScale, .leastNonzeroMagnitude)
        self.routes = Self.prepareRoutes(
            routes,
            metersPerLongitudeDegree: metersPerLongitudeDegree
        )
    }

    func positioned(in viewport: TransitMapViewport) -> [NetworkRoute] {
        guard
            viewport.width > 0,
            viewport.height > 0,
            viewport.latitudeDelta > 0,
            viewport.longitudeDelta > 0
        else {
            return routes.map(\.source)
        }

        let longitudePerPoint = viewport.longitudeDelta / viewport.width
        let latitudePerPoint = viewport.latitudeDelta / viewport.height

        return routes.map { route in
            NetworkRoute(
                badge: route.source.badge,
                segments: route.segments.map { segment in
                    NetworkSegment(
                        id: segment.id,
                        coordinates: segment.points.map { point in
                            guard
                                point.laneRouteIDs.count > 1,
                                let routeIndex = point.laneRouteIDs.firstIndex(of: route.source.id)
                            else { return point.coordinate }

                            let lane = Double(routeIndex) -
                                Double(point.laneRouteIDs.count - 1) / 2
                            let screenTangent = Self.normalize(
                                Vector(
                                    x: point.tangent.x /
                                        metersPerLongitudeDegree /
                                        longitudePerPoint,
                                    y: -point.tangent.y /
                                        Self.metersPerLatitudeDegree /
                                        latitudePerPoint
                                )
                            )
                            let offsetPoints = lane * viewport.laneSpacingPoints
                            let offsetX = -screenTangent.y * offsetPoints
                            let offsetY = screenTangent.x * offsetPoints

                            return GeoCoordinate(
                                latitude: point.anchor.y / Self.metersPerLatitudeDegree -
                                    offsetY * latitudePerPoint,
                                longitude: point.anchor.x / metersPerLongitudeDegree +
                                    offsetX * longitudePerPoint
                            )
                        }
                    )
                }
            )
        }
    }
}

private extension TransitRouteLayout {
    struct Point: Sendable, Hashable {
        let x: Double
        let y: Double
    }

    struct Vector: Sendable, Hashable {
        let x: Double
        let y: Double
    }

    struct LayoutPoint: Sendable {
        let anchor: Point
        let coordinate: GeoCoordinate
        let laneRouteIDs: [RouteID]
        let tangent: Vector
    }

    struct LayoutSegment: Sendable {
        let id: String
        let points: [LayoutPoint]
    }

    struct LayoutRoute: Sendable {
        let source: NetworkRoute
        let segments: [LayoutSegment]
    }

    struct Edge: Sendable {
        let start: Point
        let end: Point
        let routeID: RouteID
        let tangent: Vector
    }

    struct Match: Sendable {
        let point: Point
        let routeID: RouteID
    }

    struct GridCell: Hashable {
        let x: Int
        let y: Int
    }

    static func prepareRoutes(
        _ routes: [NetworkRoute],
        metersPerLongitudeDegree: Double
    ) -> [LayoutRoute] {
        func projected(_ coordinate: GeoCoordinate) -> Point {
            Point(
                x: coordinate.longitude * metersPerLongitudeDegree,
                y: coordinate.latitude * metersPerLatitudeDegree
            )
        }

        let routeOrder = Dictionary(
            uniqueKeysWithValues: routes.enumerated().map { ($0.element.id, $0.offset) }
        )
        let edges = buildEdges(routes: routes, projected: projected)
        let edgeGrid = indexEdges(edges)

        return routes.map { route in
            LayoutRoute(
                source: route,
                segments: route.segments.map { segment in
                    let sourceProjectedPoints = segment.coordinates.map(projected)
                    let projectedPoints = densified(sourceProjectedPoints)
                    let tangents = projectedPoints.indices.map { index in
                        pointTangent(points: projectedPoints, index: index)
                    }
                    let matches = projectedPoints.indices.map { index in
                        corridorMatches(
                            point: projectedPoints[index],
                            tangent: tangents[index],
                            routeID: route.id,
                            edges: edges,
                            edgeGrid: edgeGrid
                        )
                    }
                    let retainedMatches = retainCorridorRuns(
                        points: projectedPoints,
                        matches: matches
                    )
                    guard retainedMatches.contains(where: { !$0.isEmpty }) else {
                        let sourceTangents = sourceProjectedPoints.indices.map { index in
                            pointTangent(points: sourceProjectedPoints, index: index)
                        }
                        return LayoutSegment(
                            id: segment.id,
                            points: segment.coordinates.indices.map { index in
                                LayoutPoint(
                                    anchor: sourceProjectedPoints[index],
                                    coordinate: segment.coordinates[index],
                                    laneRouteIDs: [route.id],
                                    tangent: sourceTangents[index]
                                )
                            }
                        )
                    }

                    return LayoutSegment(
                        id: segment.id,
                        points: projectedPoints.indices.map { index in
                            let pointMatches = retainedMatches[index]
                            let laneRouteIDs = Set(
                                [route.id] + pointMatches.map(\.routeID)
                            ).sorted { first, second in
                                (routeOrder[first] ?? .max) < (routeOrder[second] ?? .max)
                            }
                            return LayoutPoint(
                                anchor: averagePoint(
                                    [projectedPoints[index]] + pointMatches.map(\.point)
                                ),
                                coordinate: GeoCoordinate(
                                    latitude: projectedPoints[index].y / metersPerLatitudeDegree,
                                    longitude: projectedPoints[index].x / metersPerLongitudeDegree
                                ),
                                laneRouteIDs: laneRouteIDs,
                                tangent: tangents[index]
                            )
                        }
                    )
                }
            )
        }
    }

    static func densified(_ points: [Point], maximumSpacingMeters: Double = 40) -> [Point] {
        guard let first = points.first else { return [] }
        var result = [first]

        for index in points.indices.dropFirst() {
            let start = points[index - 1]
            let end = points[index]
            let length = distance(start, end)
            guard length > 0 else { continue }
            let stepCount = max(1, Int(ceil(length / maximumSpacingMeters)))
            for step in 1...stepCount {
                let progress = Double(step) / Double(stepCount)
                result.append(
                    Point(
                        x: start.x + (end.x - start.x) * progress,
                        y: start.y + (end.y - start.y) * progress
                    )
                )
            }
        }
        return result
    }

    static func buildEdges(
        routes: [NetworkRoute],
        projected: (GeoCoordinate) -> Point
    ) -> [Edge] {
        routes.flatMap { route in
            route.segments.flatMap { segment in
                let points = segment.coordinates.map(projected)
                return points.indices.dropFirst().compactMap { index -> Edge? in
                    let start = points[index - 1]
                    let end = points[index]
                    let tangent = normalize(
                        Vector(x: end.x - start.x, y: end.y - start.y)
                    )
                    guard magnitude(tangent) > 0 else { return nil }
                    return Edge(
                        start: start,
                        end: end,
                        routeID: route.id,
                        tangent: tangent
                    )
                }
            }
        }
    }

    static func indexEdges(_ edges: [Edge]) -> [GridCell: [Int]] {
        var grid: [GridCell: [Int]] = [:]
        for (index, edge) in edges.enumerated() {
            let minimumX = Int(floor(min(edge.start.x, edge.end.x) /
                sharedCorridorToleranceMeters))
            let maximumX = Int(floor(max(edge.start.x, edge.end.x) /
                sharedCorridorToleranceMeters))
            let minimumY = Int(floor(min(edge.start.y, edge.end.y) /
                sharedCorridorToleranceMeters))
            let maximumY = Int(floor(max(edge.start.y, edge.end.y) /
                sharedCorridorToleranceMeters))

            for x in minimumX...maximumX {
                for y in minimumY...maximumY {
                    grid[GridCell(x: x, y: y), default: []].append(index)
                }
            }
        }
        return grid
    }

    static func corridorMatches(
        point: Point,
        tangent: Vector,
        routeID: RouteID,
        edges: [Edge],
        edgeGrid: [GridCell: [Int]]
    ) -> [Match] {
        let cellX = Int(floor(point.x / sharedCorridorToleranceMeters))
        let cellY = Int(floor(point.y / sharedCorridorToleranceMeters))
        var candidateIndexes: Set<Int> = []

        for x in (cellX - 1)...(cellX + 1) {
            for y in (cellY - 1)...(cellY + 1) {
                candidateIndexes.formUnion(edgeGrid[GridCell(x: x, y: y)] ?? [])
            }
        }

        var nearestByRoute: [RouteID: (distance: Double, point: Point)] = [:]
        for index in candidateIndexes {
            let edge = edges[index]
            guard edge.routeID != routeID else { continue }
            guard abs(dot(tangent, edge.tangent)) >= minimumParallelDotProduct else {
                continue
            }
            let nearest = nearestPointOnEdge(point: point, start: edge.start, end: edge.end)
            guard nearest.distance <= sharedCorridorToleranceMeters else { continue }
            if let current = nearestByRoute[edge.routeID], current.distance <= nearest.distance {
                continue
            }
            nearestByRoute[edge.routeID] = nearest
        }

        return nearestByRoute.map { routeID, nearest in
            Match(point: nearest.point, routeID: routeID)
        }
    }

    static func retainCorridorRuns(points: [Point], matches: [[Match]]) -> [[Match]] {
        var retained = Array(repeating: [Match](), count: matches.count)
        let matchingRouteIDs = Set(matches.flatMap { $0.map(\.routeID) })

        for routeID in matchingRouteIDs {
            var runStart: Int?
            for index in 0...matches.count {
                let isMatched = index < matches.count &&
                    matches[index].contains { $0.routeID == routeID }
                if isMatched, runStart == nil {
                    runStart = index
                }
                guard !isMatched, let start = runStart else { continue }

                let end = index - 1
                var length = 0.0
                if end > start {
                    for pointIndex in (start + 1)...end {
                        length += distance(points[pointIndex - 1], points[pointIndex])
                    }
                }

                if length >= minimumSharedCorridorMeters {
                    for pointIndex in start...end {
                        if let match = matches[pointIndex].first(where: {
                            $0.routeID == routeID
                        }) {
                            retained[pointIndex].append(match)
                        }
                    }
                }
                runStart = nil
            }
        }
        return retained
    }

    static func pointTangent(points: [Point], index: Int) -> Vector {
        let start = points[max(0, index - 1)]
        let end = points[min(points.count - 1, index + 1)]
        var tangent = normalize(Vector(x: end.x - start.x, y: end.y - start.y))
        if tangent.x < 0 || (tangent.x == 0 && tangent.y < 0) {
            tangent = Vector(x: -tangent.x, y: -tangent.y)
        }
        return tangent
    }

    static func nearestPointOnEdge(
        point: Point,
        start: Point,
        end: Point
    ) -> (distance: Double, point: Point) {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let lengthSquared = deltaX * deltaX + deltaY * deltaY
        let progress = max(
            0,
            min(
                1,
                lengthSquared == 0
                    ? 0
                    : ((point.x - start.x) * deltaX +
                        (point.y - start.y) * deltaY) / lengthSquared
            )
        )
        let nearest = Point(
            x: start.x + progress * deltaX,
            y: start.y + progress * deltaY
        )
        return (distance(point, nearest), nearest)
    }

    static func normalize(_ vector: Vector) -> Vector {
        let length = magnitude(vector)
        return length == 0
            ? Vector(x: 0, y: 0)
            : Vector(x: vector.x / length, y: vector.y / length)
    }

    static func averagePoint(_ points: [Point]) -> Point {
        Point(
            x: points.reduce(0) { $0 + $1.x } / Double(points.count),
            y: points.reduce(0) { $0 + $1.y } / Double(points.count)
        )
    }

    static func magnitude(_ vector: Vector) -> Double {
        hypot(vector.x, vector.y)
    }

    static func dot(_ first: Vector, _ second: Vector) -> Double {
        first.x * second.x + first.y * second.y
    }

    static func distance(_ first: Point, _ second: Point) -> Double {
        hypot(first.x - second.x, first.y - second.y)
    }
}
