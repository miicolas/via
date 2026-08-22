import SwiftUI

struct StationDetailHeaderView: View {
  var stationName: String
  var routes: [RouteBadge]
  var accessibility: StationAccessibility?
  var peak: StationPeak?
  var distanceText: String?
  var sourceText: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      AnnotationFlowLayout(spacing: 6, maximumLineWidth: .infinity) {
        ForEach(routes) { route in
          LineBadgeView(route: route)
        }
      }

      HStack(spacing: 8) {
        if let accessibility {
          PMRBadgeView(
            condition: accessibility.condition,
            label: accessibility.label,
            comment: accessibility.comment,
            size: 24
          )
        }

        if let peak {
          StationPeakBadge(
            peak: StationPeak(
              ratio: peak.ratio,
              level: peak.level,
              label: peak.label,
              stationName: stationName
            ),
            size: 24
          )
        }
      }

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 16) {
          metadata
        }

        VStack(alignment: .leading, spacing: 6) {
          metadata
        }
      }
      .font(.callout)
      .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var metadata: some View {
    if let distanceText {
      Label(distanceText, systemImage: "location")
    }

    if let sourceText {
      Label(sourceText, systemImage: "clock")
    }
  }
}
