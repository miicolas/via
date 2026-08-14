import SwiftUI

struct LinesView: View {
    let transitAPI: any TransitAPI
    let requestedRouteID: String?

    @State private var routes: [NetworkRoute] = []
    @State private var stations: [NetworkStation] = []
    @State private var selectedRoute: NetworkRoute?
    @State private var isLoading = true
    @State private var errorMessage: String?

    init(
        transitAPI: any TransitAPI,
        requestedRouteID: String? = nil
    ) {
        self.transitAPI = transitAPI
        self.requestedRouteID = requestedRouteID
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Lignes")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(ViaTheme.ink)
                        Text("Le réseau ferré francilien, au même endroit.")
                            .font(.subheadline)
                            .foregroundStyle(ViaTheme.body)
                    }

                    if isLoading {
                        ProgressView("Chargement du réseau…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let errorMessage {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(errorMessage, systemImage: "wifi.exclamationmark")
                                .foregroundStyle(ViaTheme.critical)
                            ViaButton("Réessayer", systemImage: "arrow.clockwise", action: load)
                        }
                    } else {
                        Text("\(routes.count) lignes · \(stations.count) stations")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ViaTheme.primary)

                        LazyVStack(spacing: 10) {
                            ForEach(routes) { route in
                                LineRowView(
                                    route: route,
                                    stationCount: stationsOnRoute(route, from: stations).count,
                                    action: { selectedRoute = route }
                                )
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(ViaTheme.ground)
            .navigationTitle("Lignes")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .onChange(of: requestedRouteID) { _, _ in
                openRequestedRouteIfAvailable()
            }
            .sheet(item: $selectedRoute) { route in
                NavigationStack {
                    LineDetailView(
                        route: route,
                        stations: stationsOnRoute(route, from: stations)
                    )
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func load() {
        Task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let map = try await transitAPI.loadRailMap()
            routes = map.routes.sortedForDisplay
            stations = map.stations
            openRequestedRouteIfAvailable()
        } catch {
            errorMessage = "Le réseau est indisponible."
        }
        isLoading = false
    }

    private func openRequestedRouteIfAvailable() {
        guard let requestedRouteID,
              let route = routes.first(where: { $0.id == requestedRouteID })
        else { return }

        selectedRoute = route
    }

}
