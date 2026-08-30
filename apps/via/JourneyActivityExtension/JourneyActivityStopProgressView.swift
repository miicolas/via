import SwiftUI

/// The station-by-station line shared by the Lock Screen and expanded Island.
/// It stays secondary until the alighting stop is next, when amber plus words
/// make the warning readable without relying on colour alone.
struct JourneyActivityStopProgressView: View {
    let progress: JourneyActivityAttributes.StopProgress

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: progress.status == .current
                ? "location.circle.fill"
                : "arrow.right.circle.fill")
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)

            Text(positionTitle)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(remainingTitle)
                .fontWeight(.semibold)
                .monospacedDigit()
                .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(progress.remainingStopCount <= 1 ? Color.orange : Color.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var positionTitle: String {
        switch progress.status {
        case .current: "À \(progress.stopName)"
        case .next: "Prochain · \(progress.stopName)"
        }
    }

    private var remainingTitle: String {
        switch progress.remainingStopCount {
        case 0: "Descendez"
        case 1: "1 arrêt"
        default: "\(progress.remainingStopCount) arrêts"
        }
    }

    private var accessibilityLabel: String {
        let position = switch progress.status {
        case .current: "Station actuelle, \(progress.stopName)"
        case .next: "Prochaine station, \(progress.stopName)"
        }
        let remaining = switch progress.remainingStopCount {
        case 0: "Descendez maintenant à \(progress.alightingStopName)"
        case 1: "Votre arrêt est le prochain, \(progress.alightingStopName)"
        default: "\(progress.remainingStopCount) arrêts avant \(progress.alightingStopName)"
        }
        return "\(position). \(remaining)."
    }
}

#Preview {
    VStack(spacing: 16) {
        JourneyActivityStopProgressView(
            progress: .init(
                stopName: "Gare de Lyon",
                alightingStopName: "Nation",
                remainingStopCount: 1,
                status: .current
            )
        )
        JourneyActivityStopProgressView(
            progress: .init(
                stopName: "Nation",
                alightingStopName: "Nation",
                remainingStopCount: 0,
                status: .current
            )
        )
    }
    .padding()
    .background(.black)
    .foregroundStyle(.white)
}
