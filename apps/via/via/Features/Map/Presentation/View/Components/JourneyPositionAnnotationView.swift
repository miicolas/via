import SwiftUI

/// The traveller's marker while a journey is being followed.
///
/// A solid badge means the coordinate comes from a fresh location sample. A
/// dashed collar keeps the same character visible when the timetable is
/// carrying the position through a tunnel.
struct JourneyPositionAnnotationView: View {
    let isEstimated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        MarkBadge(
            tint: .blue,
            size: 34,
            isEstimated: isEstimated,
            showsHalo: !isEstimated && !reduceMotion
        )
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.35),
            value: isEstimated
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Votre position")
        .accessibilityValue(isEstimated ? "Position estimée selon les horaires" : "En direct")
    }
}

#Preview("Direct") {
    JourneyPositionAnnotationView(isEstimated: false)
        .padding(40)
}

#Preview("Estimé") {
    JourneyPositionAnnotationView(isEstimated: true)
        .padding(40)
}
