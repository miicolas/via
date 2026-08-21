import SwiftUI

/// Icon-only habitual station profile badge shared by journey and station surfaces.
struct StationPeakBadge: View {
    let peak: StationPeak
    let accessibilityLabel: String

    init(
        peak: StationPeak,
        accessibilityLabel: String = "Affluence habituelle"
    ) {
        self.peak = peak
        self.accessibilityLabel = accessibilityLabel
    }

    private var normalizedRatio: Double {
        min(1, max(0.25, peak.ratio))
    }

    private var tint: Color {
        switch peak.level {
        case .peak: .orange
        case .moderate: .yellow
        case .off: .secondary
        }
    }

    var body: some View {
        Label {
            Text(accessibilityLabel)
        } icon: {
            Image(systemName: "cellularbars", variableValue: normalizedRatio)
        }
            .labelStyle(.iconOnly)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
    }

    var accessibilityValue: String {
        if let stationName = peak.stationName, !stationName.isEmpty {
            return "\(stationName), \(peak.label)"
        }
        return peak.label
    }
}
