import SwiftUI

struct DepartureFreshnessView: View {
    let source: DepartureBoard.Source
    let fetchedAt: Date?

    var body: some View {
        if source == .realtime, let fetchedAt {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text("Mis à jour il y a \(ageText(at: context.date, fetchedAt: fetchedAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityLabel(
                        "Données temps réel mises à jour il y a " +
                            ageText(at: context.date, fetchedAt: fetchedAt)
                    )
            }
        }
    }

    private func ageText(at now: Date, fetchedAt: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(fetchedAt)))
        if seconds < 60 {
            return "\(seconds) s"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes) min"
        }

        return "\(minutes / 60) h \((minutes % 60)) min"
    }
}
