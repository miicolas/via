import SwiftUI

/// The journey at a glance. Places and times live in the timeline below, so
/// this strip only carries the facts that are not already visible there.
struct JourneyDetailSummaryView: View {
  let journey: Journey
  let source: JourneyResult.Source?

  var body: some View {
    ViewThatFits(in: .horizontal) {
      content
        .frame(maxWidth: .infinity, alignment: .leading)

      ScrollView(.horizontal) {
        content
          .fixedSize(horizontal: true, vertical: false)
      }
      .scrollIndicators(.hidden)
    }
    .padding(12)
    .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  private var content: some View {
    HStack(spacing: 10) {
      Image(systemName: journey.qualifier.systemImage)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(journey.qualifier.color)
        .frame(width: 34, height: 34)
        .background(journey.qualifier.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)

      if !routeBadges.isEmpty {
        HStack(spacing: 7) {
          ForEach(Array(routeBadges.enumerated()), id: \.element.id) { index, badge in
            if index > 0 {
              Image(systemName: "chevron.right")
                .routeSeparatorStyle()
            }

            LineBadgeView(route: badge, size: 26)
          }
        }
      }

      compactFact(
        JourneyFormatting.duration(journey.durationSeconds),
        systemImage: "clock"
      )
      compactFact(transferTitle, systemImage: "arrow.triangle.branch")

      if journey.walkingDurationSeconds > 0 {
        compactFact(
          JourneyFormatting.duration(journey.walkingDurationSeconds),
          systemImage: "figure.walk"
        )
      }

      if journey.status == .disrupted {
        Label("Perturbé", systemImage: "exclamationmark.triangle.fill")
          .font(.caption.weight(.bold))
          .foregroundStyle(.red)
      }

    }
  }

  private func compactFact(_ value: String, systemImage: String) -> some View {
    Label(value, systemImage: systemImage)
      .font(.subheadline.weight(.semibold).monospacedDigit())
      .foregroundStyle(.primary)
      .fixedSize()
  }

  private var transferTitle: String {
    journey.transferCount == 0 ? "Direct" : "\(journey.transferCount)"
  }

  private var transferDescription: String {
    switch journey.transferCount {
    case 0: "direct"
    case 1: "une correspondance"
    default: "\(journey.transferCount) correspondances"
    }
  }

  private var routeBadges: [RouteBadge] {
    var seen = Set<RouteID>()
    return journey.sections.compactMap(\.route).compactMap { route in
      guard seen.insert(route.id).inserted else { return nil }
      return route.badge
    }
  }

  private var accessibilityLabel: String {
    var parts = [String(localized: journey.qualifier.displayName)]
    if !routeBadges.isEmpty {
      parts.append(
        routeBadges
          .map { "\($0.mode.displayName) ligne \($0.shortName)" }
          .joined(separator: ", puis ")
      )
    }
    parts.append(JourneyFormatting.duration(journey.durationSeconds))
    parts.append(transferDescription)
    if journey.walkingDurationSeconds > 0 {
      parts.append("\(JourneyFormatting.duration(journey.walkingDurationSeconds)) de marche")
    }
    if journey.status == .disrupted { parts.append("perturbé") }
    return parts.joined(separator: ", ")
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 20) {
      JourneyDetailSummaryView(
        journey: JourneyResult.mapPreview.journeys[0],
        source: .realtime
      )

      JourneyDetailSummaryView(
        journey: JourneyResult.mapPreview.journeys[1],
        source: .theoretical
      )
    }
    .padding(16)
  }
}
