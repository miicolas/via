import Testing
@testable import Via

struct MapFlowTests {
    @Test
    func focusingSearchMovesTheFlowToSearch() {
        let state = transitionMapFlow(
            MapFlowState(),
            event: .searchFocusChanged(true)
        )

        #expect(state.screen == .search)
        #expect(state.searchFocused)
    }

    @Test
    func selectingStationExpandsTheSheetAndKeepsTheQuery() {
        var initial = MapFlowState()
        initial.searchQuery = "Châtelet"
        initial.searchFocused = true

        let state = transitionMapFlow(
            initial,
            event: .stationSelected(id: "station-1", query: "Châtelet")
        )

        #expect(state.screen == .overview)
        #expect(state.selectedStationID == "station-1")
        #expect(state.overviewDetentIndex == 2)
        #expect(state.searchQuery == "Châtelet")
    }

    @Test
    func clearingAStationReturnsToTheInitialOverview() {
        var state = MapFlowState()
        state.selectedStationID = "station-1"
        state.screen = .overview
        state.overviewDetentIndex = 3

        let next = transitionMapFlow(state, event: .stationDeselected)

        #expect(next == MapFlowState())
    }

    @Test
    func journeyFlowKeepsStationFocusAcrossResultsAndDetail() {
        var state = transitionMapFlow(
            MapFlowState(),
            event: .stationSelected(id: "station-1", query: "Châtelet")
        )

        state = transitionMapFlow(state, event: .journeyPlanningStarted)
        #expect(state.screen == .planning)
        #expect(state.selectedStationID == "station-1")

        state = transitionMapFlow(state, event: .journeyResultsReady)
        #expect(state.screen == .results)

        state = transitionMapFlow(state, event: .journeyDetailOpened(index: 1))
        #expect(state.screen == .detail)
        #expect(state.selectedJourneyIndex == 1)

        state = transitionMapFlow(state, event: .journeyDetailClosed)
        #expect(state.screen == .results)
        #expect(state.selectedStationID == "station-1")
    }

    @Test
    func mapSheetDetentEventsKeepTheExistingNonNegativeInvariant() {
        let collapsed = transitionMapFlow(
            MapFlowState(overviewDetentIndex: 0),
            event: .detentChanged(-1)
        )
        let expanded = transitionMapFlow(
            MapFlowState(overviewDetentIndex: 2),
            event: .detentChanged(8)
        )

        #expect(collapsed.overviewDetentIndex == 0)
        #expect(expanded.overviewDetentIndex == 8)
    }

    @Test
    func naturalJourneyEventsUseTheDedicatedClarificationAndResultsScreens() {
        var state = transitionMapFlow(MapFlowState(), event: .naturalJourneySubmitted)
        #expect(state.screen == .planning)

        state = transitionMapFlow(state, event: .naturalJourneyNeedsClarification)
        #expect(state.screen == .clarification)

        state = transitionMapFlow(state, event: .naturalJourneyReady)
        #expect(state.screen == .results)

        state = transitionMapFlow(state, event: .naturalJourneyCancelled)
        #expect(state.screen == .overview)
    }
}

struct LocationPermissionTests {
    @Test
    func notDeterminedNeverUsesARealCoordinate() {
        #expect(
            makeLocationState(
                for: .notDetermined,
                coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
            ) == .notDetermined
        )
    }

    @Test
    func authorizedUsesTheLatestCoordinateAndWaitsWhenMissing() {
        let coordinate = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)

        #expect(makeLocationState(for: .authorized, coordinate: coordinate) == .ready(coordinate))
        #expect(makeLocationState(for: .authorized, coordinate: nil) == .loading)
    }

    @Test
    func deniedAndRestrictedStatesStayExplicit() {
        #expect(makeLocationState(for: .denied, coordinate: nil) == .denied)
        #expect(makeLocationState(for: .restricted, coordinate: nil) == .denied)
    }
}
