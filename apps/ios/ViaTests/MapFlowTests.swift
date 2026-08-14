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
}
