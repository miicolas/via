import SwiftUI

struct MeetupParticipantRow: View {
    let participant: MeetupParticipant
    let live: MeetupLiveParticipant?
    var onRemove: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            Label(progressText, systemImage: "tram.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Label(participant.shareLevel.title, systemImage: participant.shareLevel.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .detailCard()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    avatar
                    Spacer(minLength: 8)
                    removeButton
                }
                accessibilityCopy
            }
        } else {
            HStack(spacing: 12) {
                avatar
                regularCopy
                Spacer(minLength: 8)
                removeButton
            }
        }
    }

    private var avatar: some View {
        InitialsAvatarView(
            name: participant.displayName,
            initials: initials,
            size: 50,
            tint: participant.role == .organizer ? .orange : .blue,
            isLive: live?.freshness == .live
        )
    }

    private var regularCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(participant.displayName)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if participant.role == .organizer {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Organisateur")
                }
            }
            freshness
        }
    }

    private var accessibilityCopy: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(participant.displayName)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            if participant.role == .organizer {
                Label("Organisateur", systemImage: "crown.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            freshness
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var freshness: some View {
        Text(freshnessLabel)
            .font(.caption.weight(.medium))
            .foregroundStyle(freshnessColor)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var removeButton: some View {
        if let onRemove {
            Button(
                "Retirer \(participant.displayName)",
                systemImage: "person.fill.xmark",
                role: .destructive,
                action: onRemove
            )
            .iconAction(size: .regular)
            .tint(.red)
        }
    }

    private var initials: String {
        participant.displayName.split(separator: " ").prefix(2).compactMap(\.first)
            .map(String.init).joined().uppercased()
    }

    private var progressText: String {
        let value: String
        if let station = live?.progress?.station?.name {
            value = station
        } else if let status = live?.progress?.status {
            value = switch status {
            case .planned: "Trajet prévu"
            case .waiting: "Attend son départ"
            case .underway: "En route"
            case .missed: "Correspondance ratée"
            case .joined: "Avec le groupe"
            case .arrived: "Arrivé"
            case .stopped: "Partage arrêté"
            }
        } else if let station = participant.firstBoardingStation?.name {
            value = station
        } else {
            value = switch participant.state {
            case .configuring: "Configuration en cours"
            case .ready: "Prêt à partir"
            case .underway: "En route"
            case .joined: "Avec le groupe"
            case .arrived: "Arrivé"
            case .declined: "Invitation refusée"
            case .left: "A quitté le rendez-vous"
            case .removed: "Retiré du rendez-vous"
            }
        }

        guard showsLiveZone else { return value }
        return "\(value) · \(participant.zone.title)"
    }

    private var showsLiveZone: Bool {
        guard live?.freshness != .offline else { return false }
        if let status = live?.progress?.status {
            return status == .waiting || status == .underway || status == .joined
        }
        return false
    }

    private var freshnessColor: Color {
        switch live?.freshness {
        case .live: .green
        case .delayed: .orange
        case .stale: .secondary
        case .offline, nil: .secondary
        }
    }

    private var freshnessLabel: String {
        switch live?.freshness {
        case .live: "En direct"
        case .delayed: "Signal retardé"
        case .stale: "Dernière position ancienne"
        case .offline, nil: participant.state == .arrived ? "Arrivé" : "Hors direct"
        }
    }
}
