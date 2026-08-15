import SwiftUI

struct JourneyOptionRow: View {
    let journey: Journey
    let isRecommended: Bool
    let action: () -> Void

    var body: some View {
        ViaButton(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(journeyMinutes(journey.durationSeconds)) min")
                        .font(ViaFont.title3Digit)
                        .foregroundStyle(ViaTheme.ink)
                    Spacer()
                    Text(journeyTimeLabel(journey.arrivalAt) ?? "")
                        .font(ViaFont.subheadlineDigit)
                        .foregroundStyle(ViaTheme.body)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ViaTheme.muted)
                }

                HStack(spacing: 8) {
                    ForEach(journeySegments(journey)) { segment in
                        segmentView(segment)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    Text(isRecommended ? "Recommandé" : qualifierLabel(journey.qualifier))
                        .font(ViaFont.captionSemibold)
                        .foregroundStyle(isRecommended ? ViaTheme.primary : ViaTheme.muted)
                    if journey.transferCount > 0 {
                        Text("· \(journey.transferCount) correspondance\(journey.transferCount > 1 ? "s" : "")")
                            .font(ViaFont.caption)
                            .foregroundStyle(ViaTheme.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("via.journey.\(journey.id)")
    }

    @ViewBuilder
    private func segmentView(_ segment: JourneySegment) -> some View {
        switch segment.kind {
        case .transit:
            if let route = segment.route {
                LineBadgeView(
                    route: RouteBadge(
                        id: route.id,
                        shortName: route.shortName,
                        mode: route.mode,
                        color: route.color,
                        textColor: route.textColor
                    )
                )
                .frame(width: 28, height: 28)
            }
        case .walk:
            Image(systemName: "figure.walk")
                .foregroundStyle(ViaTheme.muted)
        case .wait:
            Image(systemName: "clock")
                .foregroundStyle(ViaTheme.muted)
        }
    }

    private func qualifierLabel(_ qualifier: JourneyQualifier) -> String {
        switch qualifier {
        case .recommended: "Recommandé"
        case .rapid: "Le plus rapide"
        case .lessWalking: "Le moins de marche"
        case .comfort: "Confort"
        case .walking: "À pied"
        }
    }
}
