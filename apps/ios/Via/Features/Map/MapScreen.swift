import MapKit
import SwiftUI

struct MapScreen: View {
    let model: MapFeatureModel
    let featureFlags: NativeFeatureFlags
    let onOpenChat: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: MapFeatureModel.paris.clCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    )
    @State private var sheetPresented = true

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
        TransitMapView(model: model, position: $position)
            .onAppear { model.start() }
            .onChange(of: scenePhase) { _, phase in
                model.handle(isActive: phase == .active)
            }
            .onChange(of: model.cameraTarget) { _, target in
                guard let target else { return }
                position = .region(
                    MKCoordinateRegion(
                        center: target.clCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
                    )
                )
            }
            .sheet(isPresented: $sheetPresented) {
                MapSheetView(
                    model: model,
                    featureFlags: featureFlags,
                    onOpenChat: onOpenChat
                )
                    .presentationDetents([
                        .fraction(0.14),
                        .fraction(0.42),
                        .fraction(0.70),
                        .fraction(0.90),
                    ])
                    .presentationBackgroundInteraction(.enabled)
                    .interactiveDismissDisabled()
            }
            .toolbar(.hidden, for: .navigationBar)
    }
}
