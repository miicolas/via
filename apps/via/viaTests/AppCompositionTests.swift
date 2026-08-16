import XCTest
@testable import Via

final class AppCompositionTests: XCTestCase {
    @MainActor
    func testLiveGraphContainsOnlyCoherentProductionDependencies() throws {
        let dependencies = try AppDependencies.live(
            configuration: AppConfiguration(
                apiBaseURL: URL(string: "https://api.via.example")!
            )
        )

        XCTAssertEqual(dependencies.authSession.state, .loading)
        XCTAssertEqual(dependencies.root.account.state, .inactive)
        XCTAssertEqual(dependencies.root.networkMap.state, .idle)
        XCTAssertEqual(
            storedPropertyNames(of: dependencies),
            Set(["authSession", "root"])
        )
        XCTAssertEqual(
            storedPropertyNames(of: dependencies.root),
            Set(["account", "makeDeparturesViewModel", "networkMap"])
        )

        let departures = dependencies.root.makeDeparturesViewModel(
            StationID(rawValue: "station")
        )
        XCTAssertEqual(departures.state, .idle)
    }

    @MainActor
    func testPreviewRestoresAndLoadsWithoutAnyLiveAdapter() async {
        let dependencies = AppDependencies.preview

        await dependencies.authSession.restore()
        guard case .authenticated(let session, .online) = dependencies.authSession.state else {
            XCTFail("The preview session should restore through the memory client")
            return
        }
        XCTAssertEqual(session.user.id, "preview-user")
        guard case .active = dependencies.root.account.state else {
            XCTFail("Authentication and RootDependencies must share AccountModel")
            return
        }

        dependencies.root.networkMap.viewportChanged(
            to: NetworkViewport(
                center: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
                latitudeDelta: 0.009,
                longitudeDelta: 0.009,
                width: 400,
                height: 800
            ),
            phase: .ended
        )
        await waitUntil { dependencies.root.networkMap.state.loading == .loaded }
        XCTAssertFalse(dependencies.root.networkMap.state.snapshot.stations.isEmpty)

        let departures = dependencies.root.makeDeparturesViewModel(
            StationID(rawValue: "preview-station")
        )
        departures.start()
        await waitUntil {
            if case .loaded = departures.state { return true }
            return false
        }
        departures.stop()
    }

    @MainActor
    func testInvalidConfigurationDoesNotBuildOrFallbackToAWorkingGraph() {
        var didBuildDependencies = false

        let state = AppBootstrapState.bootstrap(
            loadConfiguration: {
                throw ViaError.invalidConfiguration("missing URL")
            },
            buildDependencies: { _ in
                didBuildDependencies = true
                return .preview
            }
        )

        XCTAssertFalse(didBuildDependencies)
        guard case .failed(.invalidConfiguration(let message)) = state else {
            XCTFail("Invalid configuration must produce the blocking failure state")
            return
        }
        XCTAssertEqual(message, "missing URL")
    }

    @MainActor
    private func waitUntil(
        _ predicate: @escaping @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<150 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition was not met", file: file, line: line)
    }

    private func storedPropertyNames<Value>(of value: Value) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap(\.label))
    }
}
