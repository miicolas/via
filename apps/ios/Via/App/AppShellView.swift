import SwiftUI

struct AppShellView: View {
    let mapModel: MapFeatureModel
    let chatModel: ChatFeatureModel
    let transitAPI: any TransitAPI
    let featureFlags: NativeFeatureFlags
    let router: AppRouter
    let navigoClient: any NavigoClient

    @SceneStorage("via.shell.selected-tab") private var selectedTab = 0
    @State private var presentedSheet: PresentedSheet?
    @State private var requestedLineID: String?

    private enum PresentedSheet: Identifiable {
        case chat
        case journey(ChatItinerary)

        var id: String {
            switch self {
            case .chat: "chat"
            case .journey(let itinerary): "journey-\(itinerary.id)"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MapScreen(
                model: mapModel,
                featureFlags: featureFlags,
                onOpenChat: { presentedSheet = .chat }
            )
            .tabItem { Label("Carte", systemImage: "map") }
            .tag(0)

            LinesView(
                transitAPI: transitAPI,
                requestedRouteID: requestedLineID
            )
                .tabItem { Label("Lignes", systemImage: "tram") }
                .tag(1)

            NavigoView(client: navigoClient)
                .tabItem { Label("Navigo", systemImage: "creditcard") }
                .tag(2)
        }
        .tint(ViaTheme.primary)
        .onAppear(perform: handlePendingRoute)
        .onChange(of: router.path) { _, _ in
            handlePendingRoute()
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .chat:
                ChatScreen(
                    model: chatModel,
                    onOpenItinerary: { itinerary in
                        presentedSheet = .journey(itinerary)
                    }
                )
                .presentationDetents([.fraction(0.70), .large])
                .presentationDragIndicator(.visible)
            case .journey(let itinerary):
                if let journey = itinerary.response.journeys.first {
                    JourneyDetailView(
                        journey: journey,
                        destination: itinerary.destination,
                        onBack: { presentedSheet = nil },
                        onCancel: { presentedSheet = nil }
                    )
                    .padding(20)
                    .presentationDetents([.large])
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Aucun trajet disponible", systemImage: "tram.circle")
                            .font(.headline)
                        Text("Via n’a pas trouvé de trajet vers \(itinerary.destination.name).")
                            .foregroundStyle(ViaTheme.body)
                        ViaButton(action: { presentedSheet = nil }) {
                            Label("Fermer", systemImage: "xmark")
                        }
                    }
                    .padding(24)
                    .presentationDetents([.fraction(0.35)])
                }
            }
        }
    }

    private func handlePendingRoute() {
        guard let route = router.path.last else { return }

        switch route {
        case .station(let id):
            selectedTab = 0
            mapModel.openStation(id: id)
        case .line(let id):
            selectedTab = 1
            requestedLineID = id
        case .chat:
            selectedTab = 0
            presentedSheet = .chat
        }

        router.consume(route)
    }
}
