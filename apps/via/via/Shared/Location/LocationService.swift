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

/// Shared owner of the single Core Location adapter used by the app.
///
/// Stations and Search both need the same current coordinate. Keeping the
/// adapter behind this model prevents the last consumer that assigns
/// `LocationAdapter.onEvent` from silently stealing location updates from the
/// other feature.
@MainActor
@Observable
final class LocationModel {
    private(set) var state: LocationState

    /// Stations observes this callback for its existing loading flow. Search
    /// waits through `requestCurrentLocation()` so it can resume a pending
    /// journey after the permission prompt completes.
    @ObservationIgnored var onStateChange: (@MainActor (LocationState) -> Void)?

    @ObservationIgnored private let adapter: any LocationAdapter

    init(adapter: any LocationAdapter) {
        self.adapter = adapter
        state = .idle(authorization: adapter.authorization)
        adapter.onEvent = { [weak self] event in
            self?.handle(event)
        }
    }

    var authorization: LocationAuthorization {
        switch state {
        case .idle(let authorization), .failed(let authorization):
            authorization
        case .locating:
            adapter.authorization
        case .located:
            .authorized
        }
    }

    var coordinate: GeoCoordinate? {
        guard case .located(let coordinate) = state else { return nil }
        return coordinate
    }

    func requestLocation() {
        switch adapter.authorization {
        case .authorized:
            publish(.locating)
            adapter.requestLocation()
        case .notDetermined:
            publish(.locating)
            adapter.requestAuthorization()
        case .restricted, .denied:
            publish(.failed(adapter.authorization))
        }
    }

    /// Requests the current coordinate and waits for the adapter event. The
    /// stream is registered before requesting permission so synchronous test
    /// adapters cannot race the listener.
    func requestCurrentLocation() async -> GeoCoordinate? {
        if let coordinate { return coordinate }

        let updates = stateUpdates()
        requestLocation()

        for await update in updates {
            switch update {
            case .located(let coordinate):
                return coordinate
            case .failed:
                return nil
            case .idle(.denied), .idle(.restricted):
                return nil
            case .locating, .idle:
                continue
            }
        }

        return nil
    }

    @ObservationIgnored private var updateContinuations: [UUID: AsyncStream<LocationState>.Continuation] = [:]

    private func stateUpdates() -> AsyncStream<LocationState> {
        let id = UUID()
        return AsyncStream { continuation in
            updateContinuations[id] = continuation
            continuation.yield(state)
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in
                    self?.updateContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    private func handle(_ event: LocationAdapterEvent) {
        switch event {
        case .authorizationChanged(let authorization):
            switch authorization {
            case .authorized:
                publish(.locating)
                adapter.requestLocation()
            case .notDetermined:
                publish(.idle(authorization: authorization))
            case .restricted, .denied:
                publish(.failed(authorization))
            }
        case .located(let coordinate):
            publish(.located(coordinate))
        case .failed(let authorization):
            publish(.failed(authorization))
        }
    }

    private func publish(_ newState: LocationState) {
        state = newState
        onStateChange?(newState)
        for continuation in updateContinuations.values {
            continuation.yield(newState)
        }
    }
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
