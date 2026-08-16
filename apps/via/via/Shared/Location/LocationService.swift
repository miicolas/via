import CoreLocation
import Foundation
import Observation
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
final class CoreLocationAdapter: NSObject, LocationAdapter, CLLocationManagerDelegate {
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
        ViaLog.location.error("Location failed: \(String(describing: error), privacy: .private(mask: .hash))")
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

@MainActor
@Observable
final class LocationViewModel {
    private(set) var state: LocationState
    private let adapter: any LocationAdapter

    init(adapter: any LocationAdapter) {
        self.adapter = adapter
        state = .idle(authorization: adapter.authorization)
        adapter.onEvent = { [weak self] event in
            self?.receive(event)
        }
    }

    func requestLocation() {
        switch adapter.authorization {
        case .notDetermined:
            adapter.requestAuthorization()
        case .authorized:
            state = .locating
            adapter.requestLocation()
        case .restricted, .denied:
            state = .failed(adapter.authorization)
        }
    }

    private func receive(_ event: LocationAdapterEvent) {
        switch event {
        case .authorizationChanged(let authorization):
            state = .idle(authorization: authorization)
            if authorization == .authorized { requestLocation() }
        case .located(let coordinate):
            state = .located(coordinate)
        case .failed(let authorization):
            state = .failed(authorization)
        }
    }
}
