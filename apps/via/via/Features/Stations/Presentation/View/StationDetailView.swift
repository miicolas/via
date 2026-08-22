import SwiftUI

/// Detail sheet stacked above the tab sheet when a station row is selected.
struct StationDetailView: View {
  let selection: SelectedStationModel
  var isLargeScreen: Bool
  @Binding var detailDetent: PresentationDetent

  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The sheet's collapsed detent only shows the navigation title, so the
  /// bottom-bar favorite control is hidden until the sheet is expanded.
  private var isCollapsed: Bool {
    detailDetent == .height(80)
  }

  var body: some View {
    NavigationStack {
      if let currentStation = selection.overview {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            StationDetailHeaderView(
              stationName: currentStation.name,
              routes: currentStation.routes,
              accessibility: currentStation.accessibility,
              peak: currentStation.peak,
              distanceText: currentStation.distanceText,
              sourceText: selection.loadingState == .loaded
                || currentStation.departureSource != .unavailable
                ? currentStation.sourceText : nil
            )

            StationDeparturesSection(
              routes: currentStation.routes,
              departures: currentStation.departures,
              source: currentStation.departureSource,
              fetchedAt: currentStation.departureFetchedAt,
              loadingState: selection.loadingState,
              onRetry: selection.retry
            )
          }
          .padding(.horizontal, 20)
          .padding(.top, 16)
          .padding(.bottom, 32)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(currentStation.name)
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button(role: .close) {
              dismiss()
            }
          }

          if !isCollapsed {
            ToolbarItem(placement: .bottomBar) {
              Button {
                selection.toggleNotificationFollow()
              } label: {
                Image(systemName: selection.isNotificationFollowed ? "bell.fill" : "bell")
              }
              .contentTransition(
                reduceMotion
                  ? .identity
                  : .symbolEffect(
                    .replace.magic(fallback: .offUp.byLayer),
                    options: .nonRepeating
                  )
              )
              .tint(selection.isNotificationFollowed ? .orange : .primary)
              .accessibilityLabel("Suivre la station")
              .accessibilityValue(selection.isNotificationFollowed ? "Activé" : "Désactivé")
              .accessibilityHint("Active ou désactive les alertes de perturbation de cette station.")
            }

            ToolbarItem(placement: .bottomBar) {
              Button {
                selection.toggleFavorite()
              } label: {
                Image(systemName: selection.isFavorite ? "star.fill" : "star")
                  .contentTransition(
                    reduceMotion
                      ? .identity
                      : .symbolEffect(
                        .replace.magic(fallback: .offUp.byLayer),
                        options: .nonRepeating
                      )
                  )
                  .animation(
                    reduceMotion ? nil : .default,
                    value: selection.isFavorite
                  )
              }
              .tint(selection.isFavorite ? .orange : .primary)
              .accessibilityLabel("Favoris")
              .accessibilityValue(selection.isFavorite ? "Ajoutée" : "Non ajoutée")
              .accessibilityHint("Ajoute ou retire cette station des favoris.")
            }

            ToolbarSpacer(.flexible, placement: .bottomBar)
          }
        }
      }
    }
    .detailSheetPresentation(isLargeScreen: isLargeScreen, selection: $detailDetent)
  }
}

#Preview {
  @Previewable @State var detailDetent: PresentationDetent = .large
  let locationModel = LocationModel(adapter: InMemoryLocationAdapter())
  let accountModel: AccountModel = {
    let model = AccountModel(
      remote: InMemoryAccountRemote(),
      synchronizationEnabled: false
    )
    model.activateAnonymous()
    return model
  }()
  let selection: SelectedStationModel = {
    let model = SelectedStationModel(
      departuresRepository: InMemoryDeparturesRepository.stationsPreview,
      account: accountModel,
      locationModel: locationModel
    )
    model.select(StationOverview.preview)
    return model
  }()

  StationDetailView(
    selection: selection,
    isLargeScreen: false,
    detailDetent: $detailDetent
  )
}
