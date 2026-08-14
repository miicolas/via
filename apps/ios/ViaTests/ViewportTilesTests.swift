import Testing
@testable import Via

struct ViewportTilesTests {
    @Test
    func tilesAreStableForAViewport() {
        let keys = ViewportTiles.keys(
            for: ViewportRegion(
                latitude: 48.8566,
                longitude: 2.3522,
                latitudeDelta: 0.02,
                longitudeDelta: 0.02
            )
        )

        #expect(keys == ["2442:117", "2442:118", "2443:117", "2443:118"])
    }

    @Test
    func tileKeysRoundTripToBounds() {
        let bounds = ViewportTiles.bounds(for: "2442:117")

        #expect(bounds?.minLatitude == 48.84)
        #expect(bounds?.maxLongitude == 2.36)
    }
}
