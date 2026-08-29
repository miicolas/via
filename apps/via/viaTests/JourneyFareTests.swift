import XCTest
@testable import Via

final class JourneyFareTests: XCTestCase {
    func testFormatsOfficialEuroTotalsInFrench() {
        XCTAssertEqual(JourneyFormatting.fare(amountInCents: 255), "2,55 €")
        XCTAssertEqual(JourneyFormatting.fare(amountInCents: 460), "4,60 €")
        XCTAssertEqual(JourneyFormatting.fare(amountInCents: 1_400), "14 €")
        XCTAssertEqual(
            JourneyFormatting.fareAccessibility(amountInCents: 460),
            "4 euros et 60 centimes"
        )
    }

    func testMapsThePlannerFareIntoTheJourneyDomain() throws {
        let payload = """
        {
          "status": "ready",
          "source": "idfm-realtime",
          "generatedAt": "2026-08-29T13:00:00Z",
          "journeys": [{
            "id": "idfm:fare",
            "qualifier": "recommended",
            "durationSeconds": 300,
            "walkingDurationSeconds": 0,
            "transferCount": 0,
            "departureAt": "2026-08-29T13:00:00Z",
            "arrivalAt": "2026-08-29T13:05:00Z",
            "status": "normal",
            "warnings": [],
            "fare": { "amountInCents": 255, "currency": "EUR" },
            "sections": [{
              "type": "transit",
              "durationSeconds": 300,
              "from": {
                "name": "Châtelet",
                "coordinate": { "latitude": 48.8583, "longitude": 2.3470 }
              },
              "to": {
                "name": "Nation",
                "coordinate": { "latitude": 48.8484, "longitude": 2.3958 }
              },
              "geometry": [],
              "route": {
                "id": "IDFM:C01371",
                "shortName": "1",
                "longName": "Métro 1",
                "mode": "metro",
                "color": "FFCD00",
                "textColor": "000000"
              },
              "stops": []
            }]
          }]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let result = try decoder.decode(
            JourneyResultDTO.self,
            from: try XCTUnwrap(payload.data(using: .utf8))
        ).domain()

        XCTAssertEqual(
            result.journeys.first?.fare,
            JourneyFare(amountInCents: 255, currency: "EUR")
        )
    }
}
