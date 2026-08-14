import SwiftUI

struct LinesView: View {
    let transitAPI: any TransitAPI

    @State private var routes: [NetworkRoute] = []
    @State private var stations: [NetworkStation] = []
    @State private var selectedRoute: NetworkRoute?
    @State private var isLoading = true
    @State private var errorMessage: String?

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
        } catch {
            errorMessage = "Le réseau est indisponible."
        }
        isLoading = false
    }

}
