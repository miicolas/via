import SwiftUI

struct MapSheetView: View {
    let model: MapFeatureModel
    let featureFlags: NativeFeatureFlags
    let onOpenChat: () -> Void

    init(
        model: MapFeatureModel,
        featureFlags: NativeFeatureFlags = NativeFeatureFlags(),
        onOpenChat: @escaping () -> Void = {}
    ) {
        self.model = model
        self.featureFlags = featureFlags
        self.onOpenChat = onOpenChat
    }

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SearchBarView(
                    query: Binding(
                        get: { model.searchQuery },
                        set: { model.setSearchQuery($0) }
                    ),
                    onFocusChanged: { model.setSearchFocused($0) }
                )

                if [.planning, .results, .detail].contains(model.flow.screen) {
                    JourneyScreen(model: model)
                } else if let station = model.selectedStation {
                    StationDetailsView(
                        station: station,
                        routes: stationRoutes(for: station, model: model),
                        departuresState: model.departuresState,
                        canPlanJourney: featureFlags.classicJourneysEnabled,
                        onClose: model.closeSelectedStation,
                        onPlanJourney: model.planSelectedStation
                    )
                } else if !model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    SearchResultsView(
                        state: model.searchState,
                        onSelect: model.selectSearchResult,
                        onRetry: { model.setSearchQuery(model.searchQuery) }
                    )
                } else {
                    overview(model: model)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func overview(model: MapFeatureModel) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Où allez-vous ?")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(ViaTheme.ink)
                    Text("Paris et Île-de-France")
                        .font(.subheadline)
                        .foregroundStyle(ViaTheme.muted)
                }
                Spacer()
                if case .ready = model.networkState {
                    Label("En direct", systemImage: "circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ViaTheme.primary)
                }
            }

            switch model.networkState {
            case .loading:
                ProgressView("Chargement du réseau…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .failed:
                VStack(alignment: .leading, spacing: 10) {
                    Label("Le réseau ne peut pas être chargé pour le moment.", systemImage: "wifi.exclamationmark")
                        .foregroundStyle(ViaTheme.critical)
                    ViaButton("Réessayer", systemImage: "arrow.clockwise", action: model.loadNetwork)
                }
            case .ready:
                if featureFlags.chatEnabled {
                    ViaButton("Parler à Via", systemImage: "sparkles", action: onOpenChat)
                        .accessibilityIdentifier("via.openChat")
                }
                linePicker(model: model)
                nearbyStations(model: model)
            }
        }
    }

    @ViewBuilder
    private func linePicker(model: MapFeatureModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lignes affichées")
                .font(.headline)
                .foregroundStyle(ViaTheme.ink)
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(model.mapRoutes) { route in
                        LineBadgeView(
                            route: RouteBadge(
                                id: route.id,
                                shortName: route.shortName,
                                mode: route.mode,
                                color: route.color,
                                textColor: route.textColor
                            )
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func nearbyStations(model: MapFeatureModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stations à proximité")
                .font(.headline)
                .foregroundStyle(ViaTheme.ink)

            ForEach(model.nearbyStations) { station in
                StationRowView(
                    station: station,
                    routes: stationRoutes(for: station, model: model),
                    distanceMeters: model.distanceMeters(to: station.coordinate),
                    action: { model.selectStation(station) }
                )
            }
        }
    }

    private func stationRoutes(for station: NetworkStation, model: MapFeatureModel) -> [RouteBadge] {
        station.routeIds.compactMap { id in
            model.mapRoutes.first(where: { $0.id == id }).map {
                RouteBadge(
                    id: $0.id,
                    shortName: $0.shortName,
                    mode: $0.mode,
                    color: $0.color,
                    textColor: $0.textColor
                )
            }
        }
    }
}
