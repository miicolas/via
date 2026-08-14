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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MapSheetContainerView(
                    model: model,
                    featureFlags: featureFlags,
                    maxHeight: sheetMaxHeight,
                    onOpenChat: onOpenChat,
                    onDragEnded: model.changeSheetDetent
                )
            }
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
            .toolbar(.hidden, for: .navigationBar)
    }

    private var sheetMaxHeight: CGFloat {
        switch model.flow.screen {
        case .planning, .clarification, .results, .detail:
            620
        case .search:
            480
        case .overview where model.flow.overviewDetentIndex <= 0:
            140
        case .overview where model.flow.overviewDetentIndex == 1:
            360
        case .overview:
            620
        }
    }
}
