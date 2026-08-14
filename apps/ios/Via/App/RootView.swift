import SwiftUI

struct RootView: View {
    @State private var router = AppRouter()
    @State private var mapModel: MapFeatureModel

    init(dependencies: AppDependencies) {
        _mapModel = State(
            initialValue: MapFeatureModel(
                transitAPI: dependencies.transitAPI,
                locationProvider: dependencies.locationProvider
            )
        )
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            MapScreen(model: mapModel)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .station:
                        MapScreen(model: mapModel)
                    }
                }
        }
    }
}
