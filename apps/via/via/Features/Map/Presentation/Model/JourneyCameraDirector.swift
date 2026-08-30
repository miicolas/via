import MapKit
import SwiftUI

/// Owns the map camera: the opening frame, the follow-the-traveller state of
/// guidance, and the overview framing of a drawn journey.
///
/// The shell only forwards events — a location fix, a tracking flip, a section
/// advance — together with the values they need. The director holds no model
/// references, so every camera decision stays testable with plain values, and
/// it composes the two tested helpers rather than replacing them:
/// `MapOpeningCamera` chooses the first frame, `JourneyTrackingCamera` shapes
/// the route-aware follow camera.
@MainActor
@Observable
final class JourneyCameraDirector {
    var position: MapCameraPosition

    /// A pan, zoom, pitch, or rotation hands the camera back to the traveller.
    /// The route-aware location button is the only gesture that resumes follow.
    private(set) var followsLocation = false

    /// A cached fix can choose the first frame immediately. Otherwise Paris is
    /// temporary until the first location answer; after that the camera is the
    /// traveller's, whether the answer was inside the service area or not.
    private(set) var hasResolvedOpeningLocation: Bool

    init(openingCoordinate: GeoCoordinate?) {
        position = .region(MapOpeningCamera.region(for: openingCoordinate))
        hasResolvedOpeningLocation = openingCoordinate != nil
    }

    /// The traveller moved the map themselves: follow ends until they ask for
    /// it back through `recenter`.
    func travellerMoved() {
        guard followsLocation else { return }
        followsLocation = false
    }

    /// A location fix arrived: resolve the opening frame once, then keep the
    /// follow camera on the traveller.
    func locationChanged(
        _ coordinate: GeoCoordinate?,
        tracking: JourneyTrackingCamera?,
        reducesMotion: Bool
    ) {
        resolveOpeningLocation(coordinate, reducesMotion: reducesMotion)
        updateTracking(tracking, reducesMotion: reducesMotion)
    }

    /// Guidance started or ended: follow mirrors tracking.
    func trackingChanged(
        isTracking: Bool,
        tracking: JourneyTrackingCamera?,
        reducesMotion: Bool
    ) {
        followsLocation = isTracking
        if isTracking {
            updateTracking(tracking, reducesMotion: reducesMotion)
        }
    }

    /// Guidance advanced to another section. Rail and waiting legs keep an
    /// overview; the close third-person camera is reserved for geometry the
    /// traveller moves through on foot or by bike.
    func sectionChanged(
        tracking: JourneyTrackingCamera?,
        journeyFrame: @autoclosure () -> MKMapRect?,
        reducesMotion: Bool
    ) {
        if followsLocation, tracking == nil {
            frame(journeyFrame())
        } else {
            updateTracking(tracking, reducesMotion: reducesMotion)
        }
    }

    /// The journey drawn on the map changed: keep the follow camera while
    /// tracking, frame the whole journey otherwise.
    func presentationChanged(
        isTracking: Bool,
        tracking: JourneyTrackingCamera?,
        mapRect: @autoclosure () -> MKMapRect?,
        reducesMotion: Bool
    ) {
        if isTracking {
            updateTracking(tracking, reducesMotion: reducesMotion)
            return
        }
        frame(mapRect())
    }

    /// Reduce Motion flipped: re-snap the follow camera without animating so
    /// the pitch and heading change does not itself become motion.
    func motionChanged(tracking: JourneyTrackingCamera?, reducesMotion: Bool) {
        updateTracking(tracking, animated: false, reducesMotion: reducesMotion)
    }

    /// The route-aware location button: the one gesture that resumes follow.
    func recenter(tracking: JourneyTrackingCamera?, reducesMotion: Bool) {
        followsLocation = true
        updateTracking(tracking, reducesMotion: reducesMotion)
    }

    /// Frames the given journey rect, without deriving a synthetic position.
    func frame(_ mapRect: MKMapRect?) {
        guard let mapRect else { return }
        position = .rect(mapRect)
    }

    private func resolveOpeningLocation(
        _ coordinate: GeoCoordinate?,
        reducesMotion: Bool
    ) {
        guard let coordinate, !hasResolvedOpeningLocation else { return }
        hasResolvedOpeningLocation = true
        // Only an untouched opening camera may jump. If the traveller has
        // already moved the map while the fix was in flight, the map is theirs.
        guard let region = position.region,
              MapOpeningCamera.isUntouchedFallback(region),
              let userRegion = MapOpeningCamera.userRegion(for: coordinate)
        else { return }
        withAnimation(reducesMotion ? nil : .easeInOut(duration: 0.4)) {
            position = .region(userRegion)
        }
    }

    private func updateTracking(
        _ tracking: JourneyTrackingCamera?,
        animated: Bool = true,
        reducesMotion: Bool
    ) {
        guard followsLocation, let tracking else { return }

        let camera = tracking.mapCamera(reducesMotion: reducesMotion)
        withAnimation(animated && !reducesMotion ? .easeInOut(duration: 0.45) : nil) {
            position = .camera(camera)
        }
    }
}
