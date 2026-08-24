import SwiftUI

struct BikeStationDetailView: View {
  var station: BikeStation
  var isLargeScreen: Bool
  @Binding var detailDetent: PresentationDetent
  var onPlanJourney: () -> Void

  @Environment(\.dismiss) private var dismiss

  /// The 80-point peek only has room for the navigation bar. Keeping the
  /// bottom action in that detent lets its safe-area inset consume the whole
  /// sheet and clip the control below the rounded edge.
  private var isCollapsed: Bool {
    detailDetent == .height(DetailSheetPresentation.collapsedHeight)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          stationIdentity

          if let availability = station.availability {
            BikeAvailabilitySummaryView(availability: availability)
          } else {
            EmptyStateView(.unavailable(
              title: "Disponibilité inconnue",
              message: "Vélib’ n’a pas fourni l’état en temps réel de cette station."
            ))
            .frame(maxWidth: .infinity)
          }

          source
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle(station.name)
      .toolbarTitleDisplayMode(isCollapsed ? .inline : .inlineLarge)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(role: .close) {
            dismiss()
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        if !isCollapsed {
          Button("Itinéraire", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
            onPlanJourney()
            dismiss()
          }
          .primaryAction()
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(.bar)
        }
      }
    }
    .detailSheetPresentation(isLargeScreen: isLargeScreen, selection: $detailDetent)
  }

  private var stationIdentity: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Vélib’ Métropole", systemImage: "bicycle")
        .font(.headline)
        .foregroundStyle(.tint)

      Text(stationDescription)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }

  private var source: some View {
    Group {
      if let lastReportedAt = station.availability?.lastReportedAt {
        Text("Actualisé \(RelativeTimeFormatting.short(lastReportedAt))")
      } else {
        Text("Données Vélib’ Métropole")
      }
    }
    .font(.footnote)
    .foregroundStyle(.tertiary)
  }

  private var stationDescription: String {
    if let stationCode = station.stationCode {
      return "Station \(stationCode) · \(station.capacity) places"
    }
    return "\(station.capacity) places"
  }
}
