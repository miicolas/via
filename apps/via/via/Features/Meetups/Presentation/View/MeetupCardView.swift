import SwiftUI

struct MeetupCardView: View {
    let meetup: Meetup

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            destination
            participantSummary

            if let warning = meetup.plan?.warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .detailCard()
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Ouvre le rendez-vous")
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                phaseBadge
                time
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                time
                Spacer(minLength: 8)
                phaseBadge
            }
        }
    }

    private var time: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(meetup.targetArrivalAt.formatted(.dateTime.weekday(.wide)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .fixedSize(horizontal: false, vertical: true)
            Text(meetup.targetArrivalAt.formatted(date: .omitted, time: .shortened))
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .layoutPriority(1)
    }

    private var phaseBadge: some View {
        MeetupPhaseBadgeView(
            phase: meetup.phase,
            isStale: meetup.plan?.isStale == true
        )
    }

    @ViewBuilder
    private var destination: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                destinationName
            }
        } else {
            Label {
                destinationName
            } icon: {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.blue)
            }
        }
    }

    private var destinationName: some View {
        Text(meetup.destination.name)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var participantSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    participantStack
                    Spacer(minLength: 8)
                    chevron
                }
                participantCount
            }
        } else {
            HStack(spacing: 12) {
                participantStack
                participantCount
                Spacer(minLength: 8)
                chevron
            }
        }
    }

    private var participantCount: some View {
        Text(participantLabel)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var chevron: some View {
        Image(systemName: "chevron.forward")
            .font(.caption.weight(.bold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    private var participantStack: some View {
        HStack(spacing: -10) {
            ForEach(Array(meetup.participants.prefix(4).enumerated()), id: \.element.id) { index, participant in
                InitialsAvatarView(
                    name: participant.displayName,
                    size: 32,
                    tint: tints[index % tints.count],
                    isLive: participant.state == .underway || participant.state == .joined
                )
                .overlay { Circle().stroke(.background, lineWidth: 2) }
                .zIndex(Double(meetup.participants.count - index))
            }
        }
        .accessibilityHidden(true)
    }

    private var participantLabel: String {
        let count = meetup.participants.count
        return count == 1 ? "1 participant" : "\(count) participants"
    }

    private var tints: [Color] { [.blue, .purple, .orange, .green] }
}
