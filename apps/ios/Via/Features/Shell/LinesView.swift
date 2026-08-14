import SwiftUI

struct LinesView: View {
    let transitAPI: any TransitAPI

    @State private var routes: [NetworkRoute] = []
    @State private var stationCount = 0
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
                        Text("\(routes.count) lignes · \(stationCount) stations")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ViaTheme.primary)

                        LazyVStack(spacing: 10) {
                            ForEach(routes) { route in
                                LineRowView(route: route, stationCount: stationCount(for: route))
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
            stationCount = map.stations.count
        } catch {
            errorMessage = "Le réseau est indisponible."
        }
        isLoading = false
    }

    private func stationCount(for route: NetworkRoute) -> Int {
        // The API currently returns route geometry and station membership separately.
        // Keeping this calculation local avoids making the shell own map state.
        max(0, stationCount / max(routes.count, 1))
    }
}
