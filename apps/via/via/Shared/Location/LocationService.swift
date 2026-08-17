import CoreLocation
import Foundation
import OSLog

enum LocationAuthorization: Sendable, Equatable {
    case notDetermined
    case restricted
    case denied
    case authorized
}

enum LocationState: Sendable, Equatable {
    case idle(authorization: LocationAuthorization)
    case locating
    case located(GeoCoordinate)
    case failed(LocationAuthorization)
}

enum LocationAdapterEvent: Sendable, Equatable {
    case authorizationChanged(LocationAuthorization)
    case located(GeoCoordinate)
    case failed(LocationAuthorization)
}

@MainActor
protocol LocationAdapter: AnyObject {
    var authorization: LocationAuthorization { get }
    var onEvent: (@MainActor (LocationAdapterEvent) -> Void)? { get set }
    func requestAuthorization()
    func requestLocation()
}

@MainActor
final class CoreLocationAdapter: NSObject, LocationAdapter, @preconcurrency CLLocationManagerDelegate {
    var onEvent: (@MainActor (LocationAdapterEvent) -> Void)?
    var authorization: LocationAuthorization { Self.map(manager.authorizationStatus) }

    private let manager: CLLocationManager

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onEvent?(.authorizationChanged(Self.map(manager.authorizationStatus)))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let value = locations.last else { return }
        onEvent?(.located(GeoCoordinate(
            latitude: value.coordinate.latitude,
            longitude: value.coordinate.longitude
        )))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        AppLog.location.error("Location failed: \(String(describing: error), privacy: .private(mask: .hash))")
        onEvent?(.failed(Self.map(manager.authorizationStatus)))
    }

    private static func map(_ value: CLAuthorizationStatus) -> LocationAuthorization {
        switch value {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorizedAlways, .authorizedWhenInUse: .authorized
        @unknown default: .denied
        }
    }
}

@MainActor
final class InMemoryLocationAdapter: LocationAdapter {
    var authorization: LocationAuthorization
    var onEvent: (@MainActor (LocationAdapterEvent) -> Void)?
    var coordinate: GeoCoordinate?

    init(
        authorization: LocationAuthorization = .authorized,
        coordinate: GeoCoordinate? = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
    ) {
        self.authorization = authorization
        self.coordinate = coordinate
    }

    func requestAuthorization() {
        if authorization == .notDetermined { authorization = .authorized }
        onEvent?(.authorizationChanged(authorization))
    }

    func requestLocation() {
        guard authorization == .authorized, let coordinate else {
            onEvent?(.failed(authorization))
            return
        }
        onEvent?(.located(coordinate))
    }
}
