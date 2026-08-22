import SwiftUI

struct JourneySummaryCard: View {
  var journey: Journey
  var source: JourneyResult.Source?
  var isSelected = false

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header
      schedule
      route
      details

      if let warning = journey.warnings.first {
        warningBanner(warning)
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(borderStyle, lineWidth: isSelected ? 2 : 0.75)
    }
    .shadow(
      color: isSelected ? Color.accentColor.opacity(0.12) : .clear,
      radius: 16,
      y: 6
    )
    .contentShape(.rect)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var header: some View {
    HStack(spacing: 10) {
      Label(journey.qualifier.displayName, systemImage: journey.qualifier.systemImage)
        .font(.caption.weight(.bold))
        .foregroundStyle(journey.qualifier.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(journey.qualifier.color.opacity(0.12), in: Capsule())

      Spacer(minLength: 8)

      if let serviceStatus {
        Label(serviceStatus.title, systemImage: serviceStatus.systemImage)
          .font(.caption.weight(.semibold))
          .foregroundStyle(serviceStatus.color)
      }

      Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
        .font(isSelected ? .body.weight(.semibold) : .caption.weight(.bold))
        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
        .contentTransition(.symbolEffect(.replace.magic(fallback: .offUp.byLayer), options: .nonRepeating))
        .accessibilityHidden(true)
    }
  }

  @ViewBuilder
  private var schedule: some View {
    if dynamicTypeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: 6) {
        scheduleTimes
        durationGuide
      }
    } else {
      HStack(alignment: .firstTextBaseline, spacing: 14) {
        scheduleTimes
        Spacer(minLength: 0)
        durationGuide
          .frame(maxWidth: 116)
      }
    }
  }

  private var scheduleTimes: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(JourneyFormatting.time(journey.departureAt))
      Image(systemName: "arrow.right")
        .font(.caption.weight(.bold))
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
      Text(JourneyFormatting.time(journey.arrivalAt))
        .foregroundStyle(.secondary)
    }
    .font(.system(.title2, design: .rounded, weight: .bold))
    .monospacedDigit()
  }

  private var durationGuide: some View {
    VStack(alignment: .trailing, spacing: 5) {
      Text(JourneyFormatting.duration(journey.durationSeconds))
        .font(.subheadline.weight(.semibold))
        .monospacedDigit()

      HStack(spacing: 0) {
        Circle()
          .frame(width: 5, height: 5)
        Rectangle()
          .frame(height: 1.5)
        Image(systemName: "arrowtriangle.right.fill")
          .font(.system(size: 7, weight: .bold))
      }
      .foregroundStyle(.tertiary)
      .accessibilityHidden(true)
    }
  }

  private var route: some View {
    HStack(spacing: 7) {
      if routeBadges.isEmpty {
        Label("À pied", systemImage: "figure.walk")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
      } else {
        Image(systemName: "figure.walk")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)

        Image(systemName: "chevron.right")
          .routeSeparatorStyle()

        ForEach(Array(routeBadges.prefix(maximumVisibleRouteBadges)).enumerated(), id: \.element.id) { index, badge in
          if index > 0 {
            Image(systemName: "chevron.right")
              .routeSeparatorStyle()
          }
          LineBadgeView(route: badge.route, size: 28)
        }

        if hiddenRouteBadgeCount > 0 {
          Image(systemName: "chevron.right")
            .routeSeparatorStyle()
          LineBadgeOverflowView(count: hiddenRouteBadgeCount, size: 28)
        }

        Image(systemName: "chevron.right")
          .routeSeparatorStyle()

        Image(systemName: "mappin.and.ellipse")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private var details: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 16) {
        detailItems
      }
      VStack(alignment: .leading, spacing: 8) {
        detailItems
      }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }

  @ViewBuilder
  private var detailItems: some View {
    Label(transferLabel, systemImage: journey.transferCount == 0 ? "arrow.right" : "arrow.triangle.branch")

    if journey.walkingDurationSeconds > 0 {
      Label(JourneyFormatting.duration(journey.walkingDurationSeconds), systemImage: "figure.walk")
    }

    if let accessibility = journey.accessibility {
      Label(accessibility.label, systemImage: "figure.roll")
        .lineLimit(1)
    }

    if let peak = journey.peak {
      Label(peak.label, systemImage: "person.2.fill")
        .lineLimit(1)
    }
  }

  private func warningBanner(_ warning: String) -> some View {
    Label(warning, systemImage: "exclamationmark.triangle.fill")
      .font(.caption.weight(.semibold))
      .foregroundStyle(.orange)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(10)
      .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var cardBackground: AnyShapeStyle {
    isSelected
      ? AnyShapeStyle(Color.accentColor.opacity(0.09))
      : AnyShapeStyle(Color.secondary.opacity(0.07))
  }

  private var borderStyle: AnyShapeStyle {
    isSelected
      ? AnyShapeStyle(.tint)
      : AnyShapeStyle(Color.primary.opacity(0.06))
  }

  private var routeBadges: [JourneyRouteBadge] {
    journey.sections.compactMap { section in
      guard let route = section.route else { return nil }
      return JourneyRouteBadge(
        id: section.id,
        route: RouteBadge(
          id: route.id,
          shortName: route.shortName,
          mode: route.mode,
          colorHex: route.colorHex,
          textColorHex: route.textColorHex
        )
      )
    }
  }

  private var maximumVisibleRouteBadges: Int {
    dynamicTypeSize.isAccessibilitySize ? 2 : 4
  }

  private var hiddenRouteBadgeCount: Int {
    max(0, routeBadges.count - maximumVisibleRouteBadges)
  }

  private var transferLabel: String {
    switch journey.transferCount {
    case 0: "Direct"
    case 1: "1 correspondance"
    default: "\(journey.transferCount) correspondances"
    }
  }

  private var serviceStatus: JourneyServiceStatus? {
    if journey.status == .disrupted {
      return JourneyServiceStatus(
        title: "Perturbé",
        systemImage: "exclamationmark.triangle.fill",
        color: .red
      )
    }
    if source == .theoretical || journey.status == .theoretical {
      return JourneyServiceStatus(
        title: "Théorique",
        systemImage: "clock",
        color: .secondary
      )
    }
    return JourneyServiceStatus(
      title: "Temps réel",
      systemImage: "dot.radiowaves.left.and.right",
      color: .green
    )
  }

  private var accessibilityLabel: String {
    var value = "\(journey.qualifier.displayName), départ à \(JourneyFormatting.time(journey.departureAt)), arrivée à \(JourneyFormatting.time(journey.arrivalAt)), \(JourneyFormatting.duration(journey.durationSeconds)), \(transferLabel)"
    if journey.walkingDurationSeconds > 0 {
      value += ", \(JourneyFormatting.duration(journey.walkingDurationSeconds)) de marche"
    }
    if let serviceStatus {
      value += ", \(serviceStatus.title)"
    }
    if let accessibility = journey.accessibility {
      value += ", \(accessibility.label)"
    }
    if let peak = journey.peak {
      value += ", affluence \(peak.label)"
    }
    if !journey.warnings.isEmpty {
      value += ", avertissement : \(journey.warnings.formatted())"
    }
    return value
  }
}

private struct JourneyRouteBadge: Identifiable {
  var id: String
  var route: RouteBadge
}

private struct JourneyServiceStatus {
  var title: LocalizedStringResource
  var systemImage: String
  var color: Color
}

private extension Journey.Qualifier {
  var displayName: LocalizedStringResource {
    switch self {
    case .recommended: "Recommandé"
    case .rapid: "Le plus rapide"
    case .lessWalking: "Moins de marche"
    case .comfort: "Le plus simple"
    case .walking: "À pied"
    }
  }

  var systemImage: String {
    switch self {
    case .recommended: "sparkles"
    case .rapid: "hare.fill"
    case .lessWalking: "figure.walk"
    case .comfort: "arrow.forward"
    case .walking: "figure.walk"
    }
  }

  var color: Color {
    switch self {
    case .recommended: .accentColor
    case .rapid: .green
    case .lessWalking: .indigo
    case .comfort: .cyan
    case .walking: .secondary
    }
  }
}

private extension Image {
  func routeSeparatorStyle() -> some View {
    font(.system(size: 8, weight: .bold))
      .foregroundStyle(.tertiary)
      .accessibilityHidden(true)
  }
}
