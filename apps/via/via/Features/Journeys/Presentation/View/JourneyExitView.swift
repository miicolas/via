import SwiftUI

/// The exit to take out of the last station, named the way its signage names it.
///
/// The number comes first when the referential has one, because that is what is
/// written above the corridor; the street name is the confirmation, not the
/// instruction.
struct JourneyExitView: View {
    let exit: JourneyExit
    var isDimmed = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.walk.departure")
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .opacity(isDimmed ? 0.45 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var title: String {
        [heading, distance].compactMap(\.self).joined(separator: " · ")
    }

    private var heading: String {
        guard let number = exit.number else { return "Sortie \(exit.name)" }
        return "Sortie \(number) · \(exit.name)"
    }

    /// Straight-line metres, so it is rounded hard enough to read as an estimate —
    /// to the nearest 50, never down, so the walk is not undersold.
    private var distance: String? {
        guard let meters = exit.walkingMeters, meters >= 50 else { return nil }
        return meters >= 1_000
            ? "\((Double(meters) / 1_000).formatted(.number.precision(.fractionLength(1)))) km"
            : "\((meters + 25) / 50 * 50) m"
    }

    var accessibilityLabel: String {
        let number = exit.number.map { "Sortie numéro \($0), " } ?? "Sortie "
        let distance = distance.map { ", à environ \($0) de votre destination" } ?? ""
        return "\(number)\(exit.name)\(distance)"
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        JourneyExitView(
            exit: JourneyExit(
                id: "IDFM:50147797",
                name: "pl. du Châtelet",
                number: 16,
                coordinate: GeoCoordinate(latitude: 48.85765, longitude: 2.34729),
                walkingMeters: 180
            )
        )
        JourneyExitView(
            exit: JourneyExit(
                id: "IDFM:50147794",
                name: "r. des Lavandières",
                number: nil,
                coordinate: GeoCoordinate(latitude: 48.85896, longitude: 2.34612),
                walkingMeters: 20
            ),
            isDimmed: true
        )
    }
    .padding()
}
