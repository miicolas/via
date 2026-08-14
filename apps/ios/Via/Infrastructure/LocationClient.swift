import CoreLocation
import Foundation

@MainActor
protocol LocationProviding: AnyObject {
    var coordinate: GeoCoordinate? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var shouldDisplayUserLocation: Bool { get }
    func requestWhenInUseAuthorization()
}

@MainActor
final class DemoLocationProvider: LocationProviding {
    let coordinate: GeoCoordinate? = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
    let authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    let shouldDisplayUserLocation = false

    func requestWhenInUseAuthorization() {}
}

@MainActor
final class LocationClient: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    private(set) var coordinate: GeoCoordinate?

    let shouldDisplayUserLocation = true

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        manager.startUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = GeoCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        Task { @MainActor [weak self] in
            self?.coordinate = coordinate
        }
    }
}
