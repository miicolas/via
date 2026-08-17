import MapKit
import SwiftUI

struct OnboardingDemoMapView: View {
    let presentation: JourneyMapPresentation?
    let reduceMotion: Bool

    @State private var position = MapCameraPosition.region(.paris)

    var body: some View {
        Map(position: $position) {
            if let presentation {
                JourneyMapContent(presentation: presentation)
            }
        }
        .mapStyle(
            .standard(
                emphasis: .muted,
                pointsOfInterest: .excludingAll
            )
        )
        .allowsHitTesting(false)
        .onChange(of: presentation) { _, newPresentation in
            guard let newPresentation else { return }

            if reduceMotion {
                position = .rect(newPresentation.cameraRect)
            } else {
                withAnimation(.easeInOut(duration: 0.8)) {
                    position = .rect(newPresentation.cameraRect)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if presentation == nil {
            return "Carte de démonstration de Paris"
        }
        return "Carte de démonstration. Itinéraire entre Hôtel de Ville et La Défense."
    }
}

#Preview {
    OnboardingDemoMapView(
        presentation: OnboardingDemoFixture.mapPresentation,
        reduceMotion: false
    )
}
