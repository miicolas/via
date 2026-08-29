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
    case updated(LocationSample)
    case failed(LocationAuthorization)
}

struct LocationSample: Codable, Sendable, Equatable {
    let coordinate: GeoCoordinate
    let horizontalAccuracy: Double?
    let recordedAt: Date
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
    @ObservationIgnored private var trackingContinuations: [UUID: AsyncStream<LocationSample>.Continuation] = [:]
    @ObservationIgnored private var allowsJourneyBackgroundUpdates = false
    @ObservationIgnored private var journeyTrackingStartedAt: Date?

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

    var backgroundAuthorizationGranted: Bool {
        adapter.backgroundAuthorizationGranted
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

        return await requestFreshLocation()
    }

    /// Requests a new fix even when a previous feature left a coordinate in
    /// the shared cache. Active journeys use this before calculating progress
    /// or a replacement itinerary.
    func requestFreshLocation(timeout: Duration? = nil) async -> GeoCoordinate? {
        guard let timeout else { return await waitForFreshLocation() }

        return await withTaskGroup(of: GeoCoordinate?.self) { group in
            group.addTask { [weak self] in
                guard let self else { return nil }
                return await self.waitForFreshLocation()
            }
            group.addTask {
                do {
                    try await Task.sleep(for: timeout)
                } catch {
                    return nil
                }
                return nil
            }

            let coordinate = await group.next() ?? nil
            group.cancelAll()
            return coordinate
        }
    }

    private func waitForFreshLocation() async -> GeoCoordinate? {
        let updates = stateUpdates(replaysCurrentState: false)
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

    /// Starts the continuous stream used only while a journey is active.
    /// The stream is registered before the adapter starts so synchronous
    /// preview adapters cannot race the first sample.
    func startJourneyTracking(
        allowsBackgroundUpdates: Bool
    ) -> AsyncStream<LocationSample> {
        let updates = trackingUpdates()
        allowsJourneyBackgroundUpdates = allowsBackgroundUpdates
        journeyTrackingStartedAt = .now
        if allowsBackgroundUpdates {
            adapter.requestBackgroundAuthorization()
        }
        adapter.startUpdatingLocation(allowsBackgroundUpdates: allowsBackgroundUpdates)
        return updates
    }

    func stopJourneyTracking() {
        adapter.stopUpdatingLocation()
        for continuation in trackingContinuations.values {
            continuation.finish()
        }
        trackingContinuations.removeAll()
        allowsJourneyBackgroundUpdates = false
        journeyTrackingStartedAt = nil
    }

    /// Nudges Core Location after connectivity returns. The location stream
    /// remains the same; this only asks the adapter to resume if it had paused
    /// updates while the traveller was underground.
    func refreshJourneyTracking() {
        guard !trackingContinuations.isEmpty else { return }
        adapter.startUpdatingLocation(allowsBackgroundUpdates: allowsJourneyBackgroundUpdates)
    }

    @ObservationIgnored private var updateContinuations: [UUID: AsyncStream<LocationState>.Continuation] = [:]

    private func stateUpdates(
        replaysCurrentState: Bool = true
    ) -> AsyncStream<LocationState> {
        let id = UUID()
        return AsyncStream { continuation in
            updateContinuations[id] = continuation
            if replaysCurrentState {
                continuation.yield(state)
            }
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in
                    self?.updateContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    private func trackingUpdates() -> AsyncStream<LocationSample> {
        let id = UUID()
        return AsyncStream { continuation in
            trackingContinuations[id] = continuation
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in
                    self?.trackingContinuations.removeValue(forKey: id)
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
                if trackingContinuations.isEmpty {
                    adapter.requestLocation()
                } else {
                    adapter.startUpdatingLocation(
                        allowsBackgroundUpdates: allowsJourneyBackgroundUpdates
                    )
                }
            case .notDetermined:
                publish(.idle(authorization: authorization))
            case .restricted, .denied:
                publish(.failed(authorization))
            }
        case .located(let coordinate):
            publish(.located(coordinate))
        case .updated(let sample):
            guard let journeyTrackingStartedAt,
                  sample.recordedAt >= journeyTrackingStartedAt.addingTimeInterval(-5) else {
                return
            }
            publish(.located(sample.coordinate))
            for continuation in trackingContinuations.values {
                continuation.yield(sample)
            }
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
    var backgroundAuthorizationGranted: Bool { get }
    var onEvent: (@MainActor (LocationAdapterEvent) -> Void)? { get set }
    func requestAuthorization()
    func requestBackgroundAuthorization()
    func requestLocation()
    func startUpdatingLocation(allowsBackgroundUpdates: Bool)
    func stopUpdatingLocation()
}

extension LocationAdapter {
    var backgroundAuthorizationGranted: Bool { false }
    func requestBackgroundAuthorization() {}
    func startUpdatingLocation(allowsBackgroundUpdates: Bool) { requestLocation() }
    func stopUpdatingLocation() {}
}

@MainActor
final class CoreLocationAdapter: NSObject, LocationAdapter, @preconcurrency CLLocationManagerDelegate {
    private static let maximumCachedLocationAge: TimeInterval = 15

    var onEvent: (@MainActor (LocationAdapterEvent) -> Void)?
    var authorization: LocationAuthorization { Self.map(manager.authorizationStatus) }
    var backgroundAuthorizationGranted: Bool { manager.authorizationStatus == .authorizedAlways }

    private let manager: CLLocationManager
    private var isTrackingJourney = false
    private var isLocatingOnce = false

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestBackgroundAuthorization() {
        guard manager.authorizationStatus == .authorizedWhenInUse else { return }
        manager.requestAlwaysAuthorization()
    }

    func requestLocation() {
        isLocatingOnce = true
        manager.startUpdatingLocation()
    }

    func startUpdatingLocation(allowsBackgroundUpdates: Bool) {
        isLocatingOnce = false
        isTrackingJourney = true
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // A 25 m cadence is adequate for section matching but makes an
        // on-foot camera visibly jump from block to block. Journey tracking is
        // already an explicit navigation session, so favour a smooth map while
        // keeping Core Location's automatic pausing and background policy.
        manager.distanceFilter = 5
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = true
        manager.allowsBackgroundLocationUpdates = allowsBackgroundUpdates
        manager.showsBackgroundLocationIndicator = allowsBackgroundUpdates
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        isLocatingOnce = false
        isTrackingJourney = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onEvent?(.authorizationChanged(Self.map(manager.authorizationStatus)))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let value = locations.last else { return }
        let coordinate = GeoCoordinate(
            latitude: value.coordinate.latitude,
            longitude: value.coordinate.longitude
        )
        if isTrackingJourney {
            onEvent?(.updated(LocationSample(
                coordinate: coordinate,
                horizontalAccuracy: value.horizontalAccuracy >= 0 ? value.horizontalAccuracy : nil,
                recordedAt: value.timestamp
            )))
        } else if isLocatingOnce,
                  value.timestamp >= Date.now.addingTimeInterval(-Self.maximumCachedLocationAge) {
            manager.stopUpdatingLocation()
            isLocatingOnce = false
            onEvent?(.located(coordinate))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        if isLocatingOnce {
            manager.stopUpdatingLocation()
            isLocatingOnce = false
        }
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
    var horizontalAccuracy: Double?
    var backgroundAuthorizationGranted = false
    private(set) var allowsBackgroundUpdates = false

    init(
        authorization: LocationAuthorization = .authorized,
        coordinate: GeoCoordinate? = GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
        horizontalAccuracy: Double? = 20
    ) {
        self.authorization = authorization
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
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

    func requestBackgroundAuthorization() {
        backgroundAuthorizationGranted = authorization == .authorized
    }

    func startUpdatingLocation(allowsBackgroundUpdates: Bool) {
        self.allowsBackgroundUpdates = allowsBackgroundUpdates
        guard authorization == .authorized, let coordinate else {
            onEvent?(.failed(authorization))
            return
        }
        onEvent?(.updated(LocationSample(
            coordinate: coordinate,
            horizontalAccuracy: horizontalAccuracy,
            recordedAt: .now
        )))
    }

    func updateJourneyLocation(
        _ coordinate: GeoCoordinate,
        horizontalAccuracy: Double? = 20,
        recordedAt: Date = .now
    ) {
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        onEvent?(.updated(LocationSample(
            coordinate: coordinate,
            horizontalAccuracy: horizontalAccuracy,
            recordedAt: recordedAt
        )))
    }
}
