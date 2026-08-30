import ActivityKit
import SwiftUI
import WidgetKit

struct MeetupActivityLockScreenView: View {
    let context: ActivityViewContext<MeetupActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: groupSymbol)
                .font(.title2)
                .foregroundStyle(groupTint)
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(context.attributes.destinationName)
                    .font(.headline)
                    .lineLimit(1)

                if let person = context.state.joinPersonName,
                   let station = context.state.joinStationName {
                    Text("\(person) · \(station)\(zoneSuffix)")
                        .font(.subheadline)
                        .lineLimit(1)
                } else {
                    Text(context.state.groupSummary)
                        .font(.subheadline)
                        .lineLimit(1)
                }

                Text(arrivalText)
                    .font(.caption)
                    .foregroundStyle(context.isStale ? .orange : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let departure = context.state.nextDepartureAt,
               context.state.groupState != .arrived,
               context.state.groupState != .ended {
                Text(timerInterval: Date.now...departure, countsDown: true)
                    .font(.caption.monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel("Temps avant le prochain départ")
            } else {
                Text(context.state.expectedArrivalAt, style: .time)
                    .font(.caption.monospacedDigit())
                    .accessibilityLabel("Arrivée prévue")
            }
        }
        .padding(16)
    }

    private var zoneSuffix: String {
        context.state.joinZone.map { " · \($0.title)" } ?? ""
    }

    private var arrivalText: String {
        if context.isStale { return "Mise à jour en attente" }
        let delta = context.state.arrivalDeltaMinutes
        if delta == 0 { return "Arrivée à l’heure" }
        return delta > 0 ? "+\(delta) min à l’arrivée" : "\(-delta) min d’avance"
    }

    private var groupSymbol: String {
        switch context.state.groupState {
        case .preparing: "clock.fill"
        case .converging: "person.2.fill"
        case .joined: "person.3.fill"
        case .fallback: "mappin.circle.fill"
        case .arrived: "checkmark.circle.fill"
        case .ended: "xmark.circle.fill"
        }
    }

    private var groupTint: Color {
        switch context.state.groupState {
        case .arrived: .green
        case .fallback: .orange
        case .ended: .secondary
        default: .blue
        }
    }
}
