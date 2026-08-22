import SwiftUI

struct StationRowLabel: View {
  let station: StationOverview

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(station.name)
          .font(.title3.weight(.semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)

        Spacer(minLength: 8)

        Image(systemName: "chevron.forward")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
      }

      VStack(alignment: .leading, spacing: 0) {
        ForEach(station.routes.enumerated(), id: \.element.id) { index, route in
          let departures = station.departures(for: route)

          if departures.isEmpty {
            DepartureLineRow(
              route: route,
              departure: nil,
              source: station.departureSource
            )
          } else {
            ForEach(departures) { departure in
              DepartureLineRow(
                route: route,
                departure: departure,
                source: station.departureSource
              )
            }
          }

          if index < station.routes.count - 1 {
            Divider()
              .padding(.leading, 52)
          }
        }
      }
    }
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityHint("Ouvre le détail de la station")
  }
}

#Preview {
  StationRowLabel(station: StationOverview.preview)
    .padding()
}
