import SwiftUI

/// Habitual station affluence, drawn as the PMR badge's twin: same glass square,
/// tint and filled bars moving with the degree, explanation one tap away.
struct StationPeakBadge: View {
    let peak: StationPeak
    var accessibilityLabel: String = "Affluence habituelle"
    var size: CGFloat = 22
    var isInteractive: Bool = true

    /// `cellularbars` carries four bars. One is always lit, so a quiet station
    /// still reads as a gauge rather than an empty square, and the busiest hour
    /// lights all four — which a raw ratio never does, since it tops out short
    /// of 1. The bars are quantised to the degree, not to the decimal.
    private var filledBars: Int {
        switch peak.level {
        case .off: 1
        case .moderate: peak.ratio >= 0.6 ? 3 : 2
        case .peak: 4
        }
    }

    var body: some View {
        InfoBadgeButton(
            symbol: "cellularbars",
            variableValue: Double(filledBars) / 4,
            tint: peak.level.tint,
            size: size,
            isInteractive: isInteractive,
            title: accessibilityLabel,
            message: message,
            accessibilityLabel: accessibilityLabel,
            accessibilityValue: accessibilityValue
        )
    }

    var accessibilityValue: String {
        if let stationName = peak.stationName, !stationName.isEmpty {
            return "\(stationName), \(peak.label)"
        }
        return peak.label
    }

    private var message: String {
        let situation: String = if let stationName = peak.stationName, !stationName.isEmpty {
            "\(stationName) : \(peak.label)"
        } else {
            "\(peak.label.prefix(1).uppercased())\(peak.label.dropFirst())"
        }

        return "\(situation), \(peak.level.explanation).\n\n\(Self.source)"
    }

    private static let source = "Profil habituel IDFM, pas du temps réel."
}

extension PeakLevel {
    var tint: Color {
        switch self {
        case .off: .green
        case .moderate: .orange
        case .peak: .red
        }
    }

    var explanation: String {
        switch self {
        case .off: "quais dégagés"
        case .moderate: "rames bien remplies"
        case .peak: "quais denses"
        }
    }
}

#Preview {
    HStack(spacing: 10) {
        StationPeakBadge(
            peak: StationPeak(ratio: 0.3, level: .off, label: "trafic creux"),
            size: 24
        )
        StationPeakBadge(
            peak: StationPeak(ratio: 0.6, level: .moderate, label: "fréquentation soutenue"),
            size: 24
        )
        StationPeakBadge(
            peak: StationPeak(
                ratio: 0.95,
                level: .peak,
                label: "heure la plus chargée",
                stationName: "Châtelet"
            ),
            size: 24
        )
    }
    .padding()
}
