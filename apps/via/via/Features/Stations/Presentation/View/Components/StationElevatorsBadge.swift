import SwiftUI

/// Elevator-state badge, drawn as the PMR badge's twin: the tint carries the
/// worst state among the station's lifts, the popover names each lift. Nothing
/// is rendered when the source references no lift here — an icon states a
/// facility, its absence states the absence.
struct StationElevatorsBadge: View {
    let snapshot: StationElevatorSnapshot
    var size: CGFloat = 22

    var body: some View {
        if snapshot.status == .unavailable || !snapshot.items.isEmpty {
            InfoBadgeButton(
                symbol: "arrow.up.arrow.down",
                tint: tint,
                size: size,
                title: "Ascenseurs",
                message: message,
                accessibilityLabel: "Ascenseurs",
                accessibilityValue: summary
            )
        }
    }

    private var unavailableCount: Int {
        snapshot.items.filter { $0.status == .unavailable }.count
    }

    private var unknownCount: Int {
        snapshot.items.filter { $0.status == .unknown }.count
    }

    private var summary: String {
        guard snapshot.status == .ok, !snapshot.items.isEmpty else {
            return "État indisponible"
        }
        if unavailableCount > 0 { return "\(unavailableCount) hors service" }
        if unknownCount > 0 { return "\(unknownCount) sans état" }
        return "Tous disponibles"
    }

    private var tint: Color {
        guard snapshot.status == .ok, !snapshot.items.isEmpty else { return .gray }
        if unavailableCount > 0 { return .red }
        if unknownCount > 0 { return .orange }
        return .green
    }

    private var message: String {
        guard snapshot.status == .ok, !snapshot.items.isEmpty else {
            return "Île-de-France Mobilités ne fournit aucun état exploitable pour le moment."
        }

        var lines = ["\(summary.prefix(1).uppercased())\(summary.dropFirst())."]
        lines.append("")
        for elevator in snapshot.items {
            lines.append(line(for: elevator))
        }

        if let sourceDate = snapshot.sourceUpdatedAt ?? snapshot.importedAt {
            lines.append("")
            lines.append(
                "Île-de-France Mobilités · mise à jour \(RelativeTimeFormatting.short(sourceDate))"
            )
        }
        return lines.joined(separator: "\n")
    }

    private func line(for elevator: StationElevator) -> String {
        var parts = [elevator.situation ?? "Ascenseur"]
        if let direction = elevator.direction { parts.append(direction) }

        var line = "\(parts.joined(separator: " · ")) — \(statusTitle(elevator.status))"
        if let reason = reasonTitle(elevator.reason) {
            line += " (\(reason))"
        }
        return line
    }

    private func statusTitle(_ status: StationElevator.Status) -> String {
        switch status {
        case .available: "disponible"
        case .unavailable: "hors service"
        case .unknown: "état inconnu"
        }
    }

    private func reasonTitle(_ reason: StationElevator.Reason?) -> String? {
        switch reason {
        case .failure: "problème technique"
        case .maintenance: "travaux ou maintenance"
        case .equipmentProblem: "autre problème d’équipement"
        case nil: nil
        }
    }
}

#Preview {
    HStack(spacing: 10) {
        StationElevatorsBadge(
            snapshot: StationElevatorSnapshot(
                status: .ok,
                sourceUpdatedAt: .now.addingTimeInterval(-540),
                importedAt: .now,
                items: [
                    StationElevator(
                        id: "1",
                        status: .available,
                        reason: nil,
                        situation: "Sortie 3",
                        direction: "Rue de Rivoli",
                        updatedAt: .now
                    ),
                    StationElevator(
                        id: "2",
                        status: .unavailable,
                        reason: .maintenance,
                        situation: "Quai direction La Défense",
                        direction: nil,
                        updatedAt: .now
                    ),
                ]
            ),
            size: 24
        )

        StationElevatorsBadge(snapshot: .unavailable, size: 24)
    }
    .padding()
}
