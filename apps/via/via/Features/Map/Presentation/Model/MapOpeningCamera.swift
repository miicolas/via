import MapKit

extension MKCoordinateRegion {
    static let paris = MKCoordinateRegion(
        center: .init(latitude: 48.8566, longitude: 2.3522),
        latitudinalMeters: 4_000,
        longitudinalMeters: 4_000
    )
}

/// Chooses the first map frame without taking the camera back after the
/// traveller starts exploring.
enum MapOpeningCamera {
    static let spanMeters = 1_200.0

    /// Geographic envelope of the eight Île-de-France departments.
    ///
    /// The app only needs a fast local gate before moving the camera; transport
    /// availability remains owned by the network repositories.
    static let ileDeFranceBounds = GeoBounds(
        minLatitude: 48.120,
        maxLatitude: 49.242,
        minLongitude: 1.446,
        maxLongitude: 3.560
    )

    static func region(for coordinate: GeoCoordinate?) -> MKCoordinateRegion {
        guard let coordinate,
              let userRegion = userRegion(for: coordinate) else { return .paris }
        return userRegion
    }

    static func userRegion(for coordinate: GeoCoordinate) -> MKCoordinateRegion? {
        guard ileDeFranceBounds.contains(coordinate) else { return nil }

        return MKCoordinateRegion(
            center: coordinate.clLocationCoordinate,
            latitudinalMeters: spanMeters,
            longitudinalMeters: spanMeters
        )
    }

    /// MapKit can normalize a requested region by a few floating-point units.
    /// A small tolerance keeps that normalization from looking like a user pan,
    /// while a real pan or zoom still makes the opening camera ineligible.
    static func isUntouchedFallback(_ region: MKCoordinateRegion) -> Bool {
        let fallback = MKCoordinateRegion.paris
        return abs(region.center.latitude - fallback.center.latitude) < 0.000_1
            && abs(region.center.longitude - fallback.center.longitude) < 0.000_1
            && abs(region.span.latitudeDelta - fallback.span.latitudeDelta) < 0.000_1
            && abs(region.span.longitudeDelta - fallback.span.longitudeDelta) < 0.000_1
    }
}
