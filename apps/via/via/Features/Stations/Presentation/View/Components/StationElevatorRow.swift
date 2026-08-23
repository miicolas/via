import SwiftUI

struct StationElevatorRow: View {
    let elevator: StationElevator

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusSystemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(statusColor)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(elevator.situation ?? "Ascenseur")
                    .font(.body.weight(.semibold))

                Text(statusTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)

                if let direction = elevator.direction {
                    Label(direction, systemImage: "arrow.trianglehead.branch")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let reasonTitle {
                    Text(reasonTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let updatedAt = elevator.updatedAt {
                    Text("État relevé \(RelativeTimeFormatting.short(updatedAt))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var statusTitle: String {
        switch elevator.status {
        case .available: "Disponible"
        case .unavailable: "Hors service"
        case .unknown: "État inconnu"
        }
    }

    private var statusSystemImage: String {
        switch elevator.status {
        case .available: "checkmark.circle.fill"
        case .unavailable: "xmark.octagon.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch elevator.status {
        case .available: .green
        case .unavailable: .red
        case .unknown: .orange
        }
    }

    private var reasonTitle: String? {
        switch elevator.reason {
        case .failure: "Problème technique"
        case .maintenance: "Travaux ou maintenance"
        case .equipmentProblem: "Autre problème d’équipement"
        case nil: nil
        }
    }
}
