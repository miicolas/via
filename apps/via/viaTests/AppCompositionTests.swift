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
            Set([
                "account",
                "makeDeparturesViewModel",
                "makeSavedPlacePicker",
                "mapPresentation",
                "nearbyStations",
                "networkMap",
            ])
        )
        XCTAssertTrue(dependencies.root.mapPresentation.state.isCompact)

        let departures = dependencies.root.makeDeparturesViewModel(
            StationID(rawValue: "station")
        )
        XCTAssertEqual(departures.state, .idle)
    }

    @MainActor
    func testPreviewRestoresAndLoadsWithoutAnyLiveAdapter() async {
        let dependencies = PreviewDependencies()

        await dependencies.authSession.restore()
        guard case .authenticated(let session, .online) = dependencies.authSession.state else {
            XCTFail("The preview session should restore through the memory client")
            return
        }
        XCTAssertEqual(session.user.id, "preview-user")
        guard case .active = dependencies.account.state else {
            XCTFail("Authentication and previews must share AccountModel")
            return
        }

        let departures = dependencies.makeDeparturesViewModel(
            for: StationID(rawValue: "preview-station")
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
            buildDependencies: { configuration in
                didBuildDependencies = true
                return try AppDependencies.live(configuration: configuration)
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
