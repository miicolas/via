import MapKit
import SwiftUI

struct MapControlClusterView: View {
  @Binding var filter: StationMapFilter
  let mapScope: Namespace.ID

  var body: some View {
    VStack(spacing: 0) {
      StationMapFilterMenu(filter: $filter)

      Divider()
        .frame(width: 28)

      MapUserLocationButton(scope: mapScope)
        .buttonStyle(.plain)
        .frame(width: 52, height: 52)
      }
    .frame(width: 52)
    .glassEffect(.regular, in: .capsule)
  }
}
