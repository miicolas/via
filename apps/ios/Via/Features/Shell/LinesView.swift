import SwiftUI

struct LinesView: View {
    let model: TransitNetworkModel
    let requestedRouteID: String?

    @State private var selectedRoute: NetworkRoute?

    init(
        model: TransitNetworkModel,
        requestedRouteID: String? = nil
    ) {
        self.model = model
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

                    if model.state == .loading {
                        ProgressView("Chargement du réseau…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if model.state == .failed {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Le réseau est indisponible.", systemImage: "wifi.exclamationmark")
                                .foregroundStyle(ViaTheme.critical)
                            ViaButton(
                                "Réessayer",
                                systemImage: "arrow.clockwise",
                                action: model.reloadNetwork
                            )
                        }
                    } else {
                        Text("\(model.routes.count) lignes · \(model.stations.count) stations")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ViaTheme.primary)

                        LazyVStack(spacing: 10) {
                            ForEach(model.routes) { route in
                                LineRowView(
                                    route: route,
                                    stationCount: stationsOnRoute(route, from: model.stations).count,
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
            .task { model.loadNetwork() }
            .onChange(of: requestedRouteID) { _, _ in
                openRequestedRouteIfAvailable()
            }
            .onChange(of: model.state) { _, state in
                guard state == .ready else { return }
                openRequestedRouteIfAvailable()
            }
            .sheet(item: $selectedRoute) { route in
                NavigationStack {
                    LineDetailView(
                        route: route,
                        stations: stationsOnRoute(route, from: model.stations)
                    )
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func openRequestedRouteIfAvailable() {
        guard let requestedRouteID,
              let route = model.routes.first(where: { $0.id == requestedRouteID })
        else { return }

        selectedRoute = route
    }

}
