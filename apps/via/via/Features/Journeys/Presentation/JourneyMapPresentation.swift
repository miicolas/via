import MapKit

struct JourneyMapPresentation: Sendable, Equatable {
    let origin: GeoCoordinate
    let destination: GeoCoordinate
    let journey: Journey?

    init(request: JourneyRequest, journey: Journey?) {
        origin = request.origin
        destination = request.destination.coordinate
        self.journey = journey
    }

    var drawableSections: [JourneySection] {
        journey?.sections.filter { $0.geometry.count >= 2 } ?? []
    }

    var cameraRect: MKMapRect {
        let coordinates = [origin, destination] + drawableSections.flatMap(\.geometry)
        let points = coordinates.map { MKMapPoint($0.clLocationCoordinate) }
        guard let first = points.first else { return .world }

        let minX = points.dropFirst().reduce(first.x) { min($0, $1.x) }
        let maxX = points.dropFirst().reduce(first.x) { max($0, $1.x) }
        let minY = points.dropFirst().reduce(first.y) { min($0, $1.y) }
        let maxY = points.dropFirst().reduce(first.y) { max($0, $1.y) }
        let mapPointsPerMeter = MKMapPointsPerMeterAtLatitude(origin.latitude)
        let minimumSpan = 700 * mapPointsPerMeter
        let width = max(maxX - minX, minimumSpan)
        let height = max(maxY - minY, minimumSpan)
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        return MKMapRect(
            x: centerX - width * 0.65,
            y: centerY - height * 0.65,
            width: width * 1.3,
            height: height * 1.3
        )
    }
}
