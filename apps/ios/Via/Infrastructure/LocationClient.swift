import CoreLocation
import Foundation

@MainActor
protocol LocationProviding: AnyObject {
    var coordinate: GeoCoordinate? { get }
    var authorization: LocationAuthorizationState { get }
    var shouldDisplayUserLocation: Bool { get }
    var onUpdate: (@MainActor (LocationUpdate) -> Void)? { get set }
    func requestWhenInUseAuthorization()
    func startUpdatingLocation()
}

@MainActor
final class DemoLocationProvider: LocationProviding {
    let coordinate: GeoCoordinate? = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
    let authorization = LocationAuthorizationState.authorized
    let shouldDisplayUserLocation = false
    var onUpdate: (@MainActor (LocationUpdate) -> Void)?

    func requestWhenInUseAuthorization() {}
    func startUpdatingLocation() {}
}

@MainActor
final class LocationClient: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    private(set) var coordinate: GeoCoordinate?

    let shouldDisplayUserLocation = true
    var onUpdate: (@MainActor (LocationUpdate) -> Void)?

    var authorization: LocationAuthorizationState {
        manager.authorizationState
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorization = manager.authorizationState
        Task { @MainActor [weak self] in
            guard let self else { return }
            onUpdate?(.authorizationChanged(authorization))
            if authorization == .authorized {
                startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = GeoCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.coordinate = coordinate
            onUpdate?(.coordinateUpdated(coordinate))
        }
    }
}

private extension CLLocationManager {
    var authorizationState: LocationAuthorizationState {
        switch authorizationStatus {
        case .notDetermined:
            .notDetermined
        case .authorizedAlways, .authorizedWhenInUse:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        @unknown default:
            .denied
        }
    }
}
