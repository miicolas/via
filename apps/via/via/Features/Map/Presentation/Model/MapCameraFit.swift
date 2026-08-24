import MapKit

/// Whether applying a filter is worth moving the camera for.
///
/// Framing the results of a filter is the obvious move and the wrong one in the
/// case that prompted it: fitting "métro" or "Vélib’" means fitting the whole
/// region, so the camera would *zoom out* and put the names further away than
/// they already were. So this only ever tightens, and only when tightening is
/// decisive — otherwise it hands back `nil` and the map stays where the
/// traveller left it.
///
/// Pure, and separate from the view, so the rule can be tested without a map.
enum MapCameraFit {
    /// Below this ratio the move is not worth the disorientation.
    static let tighteningFactor = 4.0
    /// A single result must not drop the camera onto one street corner.
    static let minimumSpanMeters = 600.0
    /// Breathing room around the outermost results.
    static let padding = 1.35

    static func fittedRegion(
        for bounds: GeoBounds,
        in current: MKCoordinateRegion
    ) -> MKCoordinateRegion? {
        guard bounds.maxLatitude >= bounds.minLatitude,
              bounds.maxLongitude >= bounds.minLongitude else { return nil }

        let center = CLLocationCoordinate2D(
            latitude: (bounds.minLatitude + bounds.maxLatitude) / 2,
            longitude: (bounds.minLongitude + bounds.maxLongitude) / 2
        )
        let minimumLatitudeDelta = minimumSpanMeters / 111_000
        let minimumLongitudeDelta = minimumSpanMeters / metersPerLongitudeDegree(at: center.latitude)

        let span = MKCoordinateSpan(
            latitudeDelta: max(
                (bounds.maxLatitude - bounds.minLatitude) * padding,
                minimumLatitudeDelta
            ),
            longitudeDelta: max(
                (bounds.maxLongitude - bounds.minLongitude) * padding,
                minimumLongitudeDelta
            )
        )

        let fitted = MKCoordinateRegion(center: center, span: span)
        guard spanMeters(of: fitted) * tighteningFactor <= spanMeters(of: current) else {
            return nil
        }
        return fitted
    }

    /// The same scalar `NetworkViewport` compares zoom levels with, so "wider"
    /// means the same thing here as it does to the station threshold.
    private static func spanMeters(of region: MKCoordinateRegion) -> Double {
        max(
            region.span.latitudeDelta * 111_000,
            region.span.longitudeDelta * metersPerLongitudeDegree(at: region.center.latitude)
        )
    }

    private static func metersPerLongitudeDegree(at latitude: Double) -> Double {
        max(1_000, 111_000 * abs(cos(latitude * .pi / 180)))
    }
}
