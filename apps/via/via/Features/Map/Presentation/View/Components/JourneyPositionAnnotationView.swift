import SwiftUI

/// The traveller's estimated position while the timetable carries guidance.
///
/// Live positions use MapKit's `UserAnnotation`. This custom twin only exists
/// because MapKit cannot place its native user dot at a simulated coordinate.
struct JourneyPositionAnnotationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.orange.opacity(reduceMotion ? 0.9 : 0.35), lineWidth: 2)
                .frame(width: 30, height: 30)

            Circle()
                .fill(.orange)
                .frame(width: 18, height: 18)
                .overlay {
                    Circle().stroke(.white, lineWidth: 3)
                }
                .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
        }
        .frame(width: 34, height: 34)
        .borderBeam(
            border: .orange,
            beam: [.clear, .orange.opacity(0.7), .yellow, .orange, .clear],
            beamBlur: 3,
            shape: Circle(),
            isEnabled: !reduceMotion
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Votre position")
        .accessibilityValue("Position estimée selon les horaires")
    }
}

#Preview("Estimé") {
    JourneyPositionAnnotationView()
        .padding(40)
}
