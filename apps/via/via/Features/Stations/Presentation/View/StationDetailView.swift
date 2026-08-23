import SwiftUI

/// Detail sheet stacked above the tab sheet when a station row is selected.
struct StationDetailView: View {
  let selection: SelectedStationModel
  var isLargeScreen: Bool
  @Binding var detailDetent: PresentationDetent

  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @State private var isNotificationAuthorizationRequested = false

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
                ? currentStation.sourceText : nil,
              sourceSystemImage: currentStation.sourceSystemImage
            )

            StationElevatorsSection(
              snapshot: currentStation.elevators,
              loadingState: selection.loadingState,
              onRetry: selection.retry
            )

            if let liveStatus = selection.liveStatus {
              StationLiveStatusSection(
                status: liveStatus,
                pendingRecoveryCategory: selection.pendingRecoveryCategory,
                onRecovery: selection.reportRecovery
              )
            }

            if let toilets = currentStation.toilets {
              StationToiletsSection(toilets: toilets)
            }

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
                // The prompt belongs to the moment someone follows the station,
                // not to a settings screen they may never open.
                if selection.toggleNotificationFollow() {
                  isNotificationAuthorizationRequested = true
                }
              } label: {
                Image(systemName: StateSymbol.bell(isOn: selection.isNotificationFollowed))
              }
              .stateSymbolTransition(value: selection.isNotificationFollowed)
              .tint(selection.isNotificationFollowed ? .orange : .primary)
              .accessibilityLabel("Suivre la station")
              .accessibilityValue(selection.isNotificationFollowed ? "Activé" : "Désactivé")
              .accessibilityHint("Active ou désactive les alertes de perturbation de cette station.")
            }

            ToolbarItem(placement: .bottomBar) {
              Button {
                selection.toggleFavorite()
              } label: {
                Image(systemName: StateSymbol.star(isOn: selection.isFavorite))
                  .stateSymbolTransition(value: selection.isFavorite)
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
    .notificationAuthorization(
      isRequested: $isNotificationAuthorizationRequested,
      message: "Autorisez les notifications dans Réglages iOS pour être prévenu des perturbations de cette station."
    )
    .task(id: LiveStatusPollingIdentity(
      stationID: selection.overview?.id,
      isActive: scenePhase == .active
    )) {
      guard scenePhase == .active else { return }
      await selection.observeLiveStatusWhileVisible()
    }
    .detailSheetPresentation(isLargeScreen: isLargeScreen, selection: $detailDetent)
  }
}

private struct LiveStatusPollingIdentity: Hashable {
  let stationID: StationID?
  let isActive: Bool
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
      reportRepository: InMemoryReportRepository(),
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
