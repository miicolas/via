import SwiftUI

/// Habitual station affluence, drawn as the PMR badge's twin: same glass square,
/// tint and filled bars moving with the degree, explanation one tap away.
struct StationPeakBadge: View {
    let peak: StationPeak
    var accessibilityLabel: String = "Affluence habituelle"
    var size: CGFloat = 22
    var isInteractive: Bool = true

    private var normalizedRatio: Double {
        min(1, max(0.25, peak.ratio))
    }

    var body: some View {
        InfoBadgeButton(
            symbol: "cellularbars",
            variableValue: normalizedRatio,
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
            "\(stationName) : \(peak.label)."
        } else {
            "\(peak.label.prefix(1).uppercased())\(peak.label.dropFirst())."
        }

        return [situation, peak.level.explanation, Self.source].joined(separator: "\n\n")
    }

    private static let source = "Profil habituel reconstitué à partir des validations IDFM (T4 2025) — ce n’est pas une mesure en temps réel."
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
        case .off:
            "Creux de fréquentation : quais dégagés, vous montez sans attendre."
        case .moderate:
            "Fréquentation soutenue : rames bien remplies, place assise incertaine."
        case .peak:
            "Heure la plus chargée : quais denses, prévoyez de laisser passer une rame."
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
