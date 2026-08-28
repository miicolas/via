import SwiftUI

/// The deep timetable sheet for one line at a selected station.
struct StationLineScheduleView: View {
  let selection: SelectedStationModel
  let route: RouteBadge
  let isLargeScreen: Bool

  @Environment(\.dismiss) private var dismiss
  @State private var detailDetent: PresentationDetent = .large

  var body: some View {
    NavigationStack {
      if let station = selection.overview {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            lineHeader(stationName: station.name)

            timetable
          }
          .padding(.horizontal, 20)
          .padding(.top, 16)
          .padding(.bottom, 32)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Ligne \(route.shortName)")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button(role: .close) {
              dismiss()
            }
          }
        }
      } else {
        EmptyStateView(
          .unavailable(
            title: "Arrêt indisponible",
            message: "Le détail de cette ligne n’est plus disponible."
          )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .task {
      guard selection.lineScheduleRoute?.id != route.id else { return }
      selection.selectLine(route)
    }
    .detailSheetPresentation(isLargeScreen: isLargeScreen, selection: $detailDetent)
  }

  private func lineHeader(stationName: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        LineBadgeView(route: route, size: 38)

        VStack(alignment: .leading, spacing: 2) {
          Text(stationName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)

          Text("Horaires de la ligne \(route.shortName)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      DepartureFreshnessView(
        source: selection.lineScheduleSource,
        fetchedAt: selection.lineScheduleFetchedAt
      )

      // The rhythm rows are the one thing on this sheet that is not obvious at
      // sight, so the sentence carries their own glyph rather than describing
      // them: the eye matches the symbol to the row it names.
      Group {
        if selection.lineScheduleTimetable.hasCadence {
          Text("Touchez \(Image(systemName: "repeat")) pour voir les horaires d’une cadence")
            .accessibilityLabel("Touchez une cadence pour voir ses horaires")
        } else {
          Label("Prévision des passages jusqu’à la fin du service", systemImage: "calendar")
        }
      }
      .font(.callout)
      .foregroundStyle(.secondary)
    }
  }

  /// The board itself, or the reason there is none. A timetable that already has
  /// rows keeps them through a failed refresh — the traveller loses the update,
  /// not the schedule they were reading.
  @ViewBuilder
  private var timetable: some View {
    if selection.lineScheduleTimetable.isEmpty {
      switch selection.lineScheduleLoadingState {
      case .idle, .loading:
        SkeletonGate(isLoading: true) {
          SkeletonList(
            count: 8,
            label: "Chargement des horaires…",
            row: .departure,
            separator: .divider(leadingInset: 50)
          )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))

      case .failed:
        EmptyStateView(
          .offline(title: "Horaires indisponibles")
        ) {
          RetryButton(action: selection.retryLineSchedule)
            .primaryAction()
        }

      case .loaded:
        // Answered, but with nothing in it: either the service day is over for
        // this line, or the operator published no timetable at all. The two are
        // not the same news.
        if selection.lineScheduleSource == .unavailable {
          EmptyStateView(
            .unavailable(
              title: "Horaires indisponibles",
              message: "La source n’a pas publié les horaires de la ligne \(route.shortName) à cet arrêt."
            )
          ) {
            RetryButton(action: selection.retryLineSchedule)
              .primaryAction()
          }
        } else {
          EmptyStateView(
            EmptyState(
              systemImage: "moon.zzz",
              title: "Plus de passage aujourd’hui",
              message: "La ligne \(route.shortName) ne dessert plus cette station jusqu’à la reprise du service."
            )
          )
        }
      }
    } else {
      VStack(alignment: .leading, spacing: 12) {
        StationLineTimetableView(
          route: route,
          timetable: selection.lineScheduleTimetable,
          source: selection.lineScheduleSource
        )

        if case .failed = selection.lineScheduleLoadingState {
          StationRefreshStatusView(
            message: "Impossible d’actualiser les horaires de cette ligne.",
            onRetry: selection.retryLineSchedule
          )
        }
      }
    }
  }
}

#Preview {
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
      crowdingRepository: InMemoryStationCrowdingRepository(crowding: .preview),
      reportRepository: InMemoryReportRepository(),
      account: accountModel,
      locationModel: locationModel
    )
    model.select(StationOverview.preview)
    return model
  }()

  StationLineScheduleView(
    selection: selection,
    route: StationOverview.preview.routes[0],
    isLargeScreen: false
  )
}
