import SwiftUI

struct JourneyTimelineRow: View {
    let schedule: JourneySectionSchedule
    @Binding var isExpanded: Bool
    let isHighlighted: Bool
    let onSelect: () -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            details
                .padding(.top, 12)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(JourneyFormatting.duration(schedule.section.durationSeconds))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .contentShape(.rect)
        }
        .tint(.primary)
        .padding(16)
        .background(Color.secondary.opacity(0.065), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.7), lineWidth: 2)
            }
        }
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
        .onChange(of: isExpanded) { _, _ in
            onSelect()
        }
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Départ", value: JourneyFormatting.time(schedule.startsAt))
            LabeledContent("Arrivée", value: JourneyFormatting.time(schedule.endsAt))

            if let direction = schedule.section.direction {
                LabeledContent("Direction", value: direction)
            }
            if let platform = schedule.section.platform {
                LabeledContent("Quai", value: platform)
            }
            if !schedule.section.stops.isEmpty {
                JourneyStopListView(stops: schedule.section.stops)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var title: String {
        switch schedule.section.kind {
        case .walk: "Marche vers \(schedule.section.to.name)"
        case .wait: "Attente à \(schedule.section.from.name)"
        case .transfer: "Correspondance vers \(schedule.section.to.name)"
        case .transit: schedule.section.route?.longName ?? "Transport"
        }
    }

    private var subtitle: String {
        switch schedule.section.kind {
        case .walk, .wait, .transfer:
            "\(schedule.section.from.name) → \(schedule.section.to.name)"
        case .transit:
            if let direction = schedule.section.direction {
                "Direction \(direction)"
            } else {
                "\(schedule.section.from.name) → \(schedule.section.to.name)"
            }
        }
    }

    private var systemImage: String {
        switch schedule.section.kind {
        case .walk: "figure.walk"
        case .wait: "clock"
        case .transfer: "arrow.triangle.turn.up.right.diamond"
        case .transit: "tram.fill"
        }
    }

    private var iconColor: Color {
        guard let route = schedule.section.route else { return .gray }
        return Color(transitHex: route.colorHex, fallback: .accentColor)
    }
}
