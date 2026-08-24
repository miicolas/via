import SwiftUI

struct BikeAvailabilitySummaryView: View {
  var availability: BikeStationAvailability

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      status

      HStack(alignment: .top, spacing: 0) {
        primaryMetric(
          availability.totalBikes,
          title: "vélos disponibles",
          systemImage: "bicycle"
        )

        Divider()
          .padding(.vertical, 4)

        primaryMetric(
          availability.docks,
          title: "places libres",
          systemImage: "parkingsign"
        )
        .padding(.leading, 12)
      }

      Divider()

      HStack(spacing: 20) {
        detailMetric(
          availability.mechanicalBikes,
          title: "mécaniques",
          systemImage: "bicycle"
        )

        detailMetric(
          availability.electricBikes,
          title: "électriques",
          systemImage: "bolt.fill"
        )
      }
    }
    .padding(18)
    .background(.quaternary.opacity(0.7), in: .rect(cornerRadius: 22))
  }

  private var status: some View {
    Label(statusTitle, systemImage: statusSystemImage)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(statusColor)
      .accessibilityLabel(statusAccessibilityLabel)
  }

  private func primaryMetric(
    _ value: Int,
    title: String,
    systemImage: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: systemImage)
          .font(.headline.weight(.semibold))
          .foregroundStyle(.tint)

        Text("\(value)")
          .font(.system(.largeTitle, design: .rounded, weight: .bold))
          .monospacedDigit()
      }

      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(value) \(title)")
  }

  private func detailMetric(
    _ value: Int,
    title: String,
    systemImage: String
  ) -> some View {
    Label {
      Text("\(value) \(title)")
        .monospacedDigit()
    } icon: {
      Image(systemName: systemImage)
        .foregroundStyle(.tint)
    }
    .font(.subheadline.weight(.medium))
    .accessibilityLabel("\(value) vélos \(title)")
  }

  private var statusTitle: String {
    guard availability.isInstalled else { return "Station hors service" }
    if availability.isRenting && availability.isReturning {
      return "Station disponible"
    }
    if availability.isRenting {
      return "Retrait uniquement"
    }
    if availability.isReturning {
      return "Retour uniquement"
    }
    return "Station indisponible"
  }

  private var statusSystemImage: String {
    availability.isRenting || availability.isReturning
      ? "checkmark.circle.fill"
      : "exclamationmark.triangle.fill"
  }

  private var statusColor: Color {
    availability.isRenting && availability.isReturning ? .green : .orange
  }

  private var statusAccessibilityLabel: String {
    "\(statusTitle). Location \(availability.isRenting ? "disponible" : "indisponible"). Retour \(availability.isReturning ? "disponible" : "indisponible")."
  }
}
