import SwiftUI

struct JourneyDetailSummaryView: View {
  let journey: Journey
  let source: JourneyResult.Source?

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        JourneyQualifierTag(
          title: qualifierTitle,
          systemImage: qualifierSymbol,
          tint: qualifierColor
        )

        Spacer(minLength: 8)

        if journey.status == .disrupted {
          Label("Perturbé", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(.red)
        }
      }

      VStack(spacing: 0) {
        JourneyEndpointRow(
          time: JourneyFormatting.time(journey.departureAt),
          name: journey.sections.first?.from.name ?? "Départ",
          position: .origin
        )

        JourneyEndpointRow(
          time: JourneyFormatting.time(journey.arrivalAt),
          name: journey.sections.last?.to.name ?? "Destination",
          position: .destination
        )
      }

      if !routeBadges.isEmpty {
        JourneyRouteStrip(badges: routeBadges)
      }

      Divider()
        .overlay(Color.primary.opacity(0.08))

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 18) {
          facts
        }

        VStack(alignment: .leading, spacing: 12) {
          facts
        }
      }

      if source == .theoretical || journey.status == .theoretical {
        Label("Horaires théoriques", systemImage: "clock.badge.questionmark")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(surface, in: shape)
    .overlay {
      shape.strokeBorder(Color.accentColor.opacity(0.16), lineWidth: 1)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  @ViewBuilder
  private var facts: some View {
    JourneySummaryFact(
      title: JourneyFormatting.duration(journey.durationSeconds),
      caption: "durée",
      systemImage: "clock"
    )
    JourneySummaryFact(
      title: transferTitle,
      caption: transferCaption,
      systemImage: "arrow.triangle.branch"
    )
    if journey.walkingDurationSeconds > 0 {
      JourneySummaryFact(
        title: JourneyFormatting.duration(journey.walkingDurationSeconds),
        caption: "de marche",
        systemImage: "figure.walk"
      )
    }
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: 26, style: .continuous)
  }

  private var surface: some ShapeStyle {
    LinearGradient(
      colors: [Color.accentColor.opacity(0.09), Color.accentColor.opacity(0.03)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var qualifierTitle: String {
    switch journey.qualifier {
    case .recommended: "Recommandé"
    case .rapid: "Le plus rapide"
    case .lessWalking: "Moins de marche"
    case .comfort: "Le plus simple"
    case .walking: "À pied"
    }
  }

  private var qualifierSymbol: String {
    switch journey.qualifier {
    case .recommended: "sparkles"
    case .rapid: "hare.fill"
    case .lessWalking: "figure.walk.motion"
    case .comfort: "leaf.fill"
    case .walking: "figure.walk"
    }
  }

  private var qualifierColor: Color {
    journey.qualifier == .recommended ? .accentColor : .secondary
  }

  private var transferTitle: String {
    journey.transferCount == 0 ? "Direct" : "\(journey.transferCount)"
  }

  private var transferCaption: String {
    switch journey.transferCount {
    case 0: "sans changement"
    case 1: "correspondance"
    default: "correspondances"
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
    var value = "\(qualifierTitle), départ de \(journey.sections.first?.from.name ?? "Départ") à \(JourneyFormatting.time(journey.departureAt))"
    value += ", arrivée à \(journey.sections.last?.to.name ?? "destination") à \(JourneyFormatting.time(journey.arrivalAt))"
    value += ", \(JourneyFormatting.duration(journey.durationSeconds))"
    value += journey.transferCount == 0
      ? ", direct"
      : ", \(journey.transferCount) \(transferCaption)"
    if journey.walkingDurationSeconds > 0 {
      value += ", \(JourneyFormatting.duration(journey.walkingDurationSeconds)) de marche"
    }
    if journey.status == .disrupted { value += ", perturbé" }
    if source == .theoretical || journey.status == .theoretical { value += ", horaires théoriques" }
    return value
  }
}

private struct JourneyQualifierTag: View {
  let title: String
  let systemImage: String
  let tint: Color

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.bold))
      .foregroundStyle(tint)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(tint.opacity(0.12), in: Capsule())
      .accessibilityHidden(true)
  }
}

private struct JourneyEndpointRow: View {
  enum Position {
    case origin
    case destination
  }

  let time: String
  let name: String
  let position: Position

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      JourneyEndpointRail(position: position)

      Text(name)
        .font(.headline)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, position == .origin ? 18 : 0)

      Spacer(minLength: 12)

      Text(time)
        .font(.system(.title3, design: .rounded).weight(.bold))
        .monospacedDigit()
        .foregroundStyle(position == .origin ? Color.primary : Color.accentColor)
    }
    .accessibilityHidden(true)
  }
}

private struct JourneyEndpointRail: View {
  let position: JourneyEndpointRow.Position

  private let markerSize: CGFloat = 11
  private let firstLineCenter: CGFloat = 10

  var body: some View {
    VStack(spacing: 0) {
      if position == .origin {
        Color.clear
          .frame(height: firstLineCenter - markerSize / 2)

        Circle()
          .strokeBorder(Color.accentColor, lineWidth: 3)
          .frame(width: markerSize, height: markerSize)

        line
          .frame(maxHeight: .infinity)
      } else {
        line
          .frame(height: firstLineCenter - markerSize / 2)

        Circle()
          .fill(Color.accentColor)
          .frame(width: markerSize, height: markerSize)

        Spacer(minLength: 0)
      }
    }
    .frame(width: markerSize)
  }

  private var line: some View {
    Capsule()
      .fill(Color.accentColor.opacity(0.28))
      .frame(width: 2)
  }
}

private struct JourneyRouteStrip: View {
  let badges: [RouteBadge]

  var body: some View {
    HStack(spacing: 6) {
      ForEach(Array(badges.enumerated()), id: \.element.id) { index, badge in
        if index > 0 {
          Image(systemName: "chevron.compact.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
        }

        LineBadgeView(route: badge, size: 28)
      }
    }
  }
}

private struct JourneySummaryFact: View {
  let title: String
  let caption: String
  let systemImage: String

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: systemImage)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.subheadline.weight(.bold))
          .monospacedDigit()

        Text(caption)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
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
