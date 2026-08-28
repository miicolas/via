import SwiftUI

/// The pinned live instruction: one action and one arrival time while the
/// remaining steps move underneath it.
struct LiveJourneyHeaderView: View {
  let journey: Journey
  let headline: JourneyGuidanceHeadline

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        leading

        VStack(alignment: .leading, spacing: 5) {
          Text(headline.title)
            .font(.title2.weight(.bold))
            .lineLimit(2)

          if let detail = headline.detail {
            Text(detail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Label(JourneyFormatting.time(journey.arrivalAt), systemImage: "flag.checkered")
          .font(.subheadline.weight(.semibold).monospacedDigit())
          .labelStyle(.titleAndIcon)
          .padding(.horizontal, 11)
          .frame(minHeight: 34)
          .background(Color.secondary.opacity(0.09), in: Capsule())
          .accessibilityLabel(
            "Arrivée prévue à \(JourneyFormatting.time(journey.arrivalAt))"
          )
      }

    }
    .padding(.horizontal, 20)
    .padding(.vertical, 18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial)
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private var leading: some View {
    if let route = headline.route {
      LineBadgeView(route: route.badge, size: 38)
    } else {
      Image(systemName: headline.symbolName)
        .font(.headline.weight(.semibold))
        .foregroundStyle(.tint)
        .frame(width: 38, height: 38)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }
  }
}
