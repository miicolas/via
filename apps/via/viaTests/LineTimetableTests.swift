import Foundation
import XCTest

@testable import Via

final class LineTimetableTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 2_000_000)

  func testRegularServiceFoldsIntoOneCadenceBehindTheExactPassages() {
    let departures = (0..<20).map { index in
      departure(id: "d\(index)", destination: "Bagneux", minutes: Double(index) * 4)
    }

    let timetable = LineTimetable.make(from: departures)

    XCTAssertEqual(
      timetable.rows.map(\.id),
      [
        "direction-Bagneux",
        "passage-d0",
        "passage-d1",
        "passage-d2",
        "cadence-d3-17",
      ]
    )
    XCTAssertEqual(timetable.departureCount, 20)
    XCTAssertTrue(timetable.hasCadence)

    guard case .cadence(let cadence) = timetable.rows[4] else {
      return XCTFail("The tail of a regular service is a cadence.")
    }
    XCTAssertEqual(cadence.headwayMinutes, 4)
    XCTAssertEqual(cadence.count, 17)
    XCTAssertEqual(cadence.startsAt, start.addingTimeInterval(3 * 4 * 60))
    XCTAssertEqual(cadence.endsAt, start.addingTimeInterval(19 * 4 * 60))
  }

  func testHeadwayChangeSplitsTheTailIntoTwoCadences() {
    var departures = (0..<8).map { index in
      departure(id: "peak\(index)", destination: "Bagneux", minutes: Double(index) * 3)
    }
    // The peak ends at minute 21; the evening runs every 8 minutes from there.
    departures += (1...8).map { index in
      departure(id: "evening\(index)", destination: "Bagneux", minutes: 21 + Double(index) * 8)
    }

    let timetable = LineTimetable.make(from: departures)
    let cadences = timetable.rows.compactMap { row -> TimetableCadence? in
      guard case .cadence(let cadence) = row else { return nil }
      return cadence
    }

    XCTAssertEqual(cadences.count, 2)
    XCTAssertEqual(cadences.first?.headwayMinutes, 3)
    XCTAssertEqual(cadences.first?.count, 5)
    XCTAssertEqual(cadences.last?.headwayMinutes, 8)
    XCTAssertEqual(cadences.last?.count, 8)
  }

  func testAMinuteOfDriftStaysOneCadence() {
    // A service that alternates four and five minutes is one rhythm to the
    // traveller, and the row claims the average rather than the first gap.
    let offsets: [Double] = [0, 4, 9, 13, 17, 22, 26, 30, 34, 39, 43, 47]
    let departures = offsets.enumerated().map { index, offset in
      departure(id: "d\(index)", destination: "Bagneux", minutes: offset)
    }

    let timetable = LineTimetable.make(from: departures)
    let cadences = timetable.rows.compactMap { row -> TimetableCadence? in
      guard case .cadence(let cadence) = row else { return nil }
      return cadence
    }

    XCTAssertEqual(cadences.count, 1)
    XCTAssertEqual(cadences.first?.count, 9)
    XCTAssertEqual(cadences.first?.headwayMinutes, 4)
  }

  func testEachDirectionKeepsItsOwnTimetableInFirstSeenOrder() {
    let bagneux = (0..<6).map { index in
      departure(id: "bagneux\(index)", destination: "Bagneux", minutes: Double(index) * 4)
    }
    let porteDeClignancourt = (0..<6).map { index in
      departure(
        id: "clignancourt\(index)",
        destination: "Porte de Clignancourt",
        minutes: 1 + Double(index) * 4
      )
    }

    // Interleaved, the way a chronological board hands them over.
    let timetable = LineTimetable.make(
      from: zip(bagneux, porteDeClignancourt).flatMap { [$0, $1] }
    )

    XCTAssertEqual(
      timetable.rows.map(\.id),
      [
        "direction-Bagneux",
        "passage-bagneux0",
        "passage-bagneux1",
        "passage-bagneux2",
        "cadence-bagneux3-3",
        "direction-Porte de Clignancourt",
        "passage-clignancourt0",
        "passage-clignancourt1",
        "passage-clignancourt2",
        "cadence-clignancourt3-3",
      ]
    )
  }

  func testACancelledPassageKeepsItsOwnRowAndBreaksTheRhythm() {
    var departures = (0..<10).map { index in
      departure(id: "d\(index)", destination: "Bagneux", minutes: Double(index) * 4)
    }
    departures[6] = departure(
      id: "d6",
      destination: "Bagneux",
      minutes: 24,
      status: .cancelled
    )

    let timetable = LineTimetable.make(from: departures)

    XCTAssertEqual(
      timetable.rows.map(\.id),
      [
        "direction-Bagneux",
        "passage-d0",
        "passage-d1",
        "passage-d2",
        "cadence-d3-3",
        "passage-d6",
        "cadence-d7-3",
      ]
    )
  }

  func testARunTooShortToBeARhythmStaysExactRows() {
    let departures = (0..<5).map { index in
      departure(id: "d\(index)", destination: "Bagneux", minutes: Double(index) * 4)
    }

    let timetable = LineTimetable.make(from: departures)

    XCTAssertEqual(
      timetable.rows.map(\.id),
      [
        "direction-Bagneux",
        "passage-d0",
        "passage-d1",
        "passage-d2",
        "passage-d3",
        "passage-d4",
      ]
    )
    XCTAssertFalse(timetable.hasCadence)
  }

  func testNoDepartureMakesAnEmptyTimetable() {
    XCTAssertTrue(LineTimetable.make(from: []).isEmpty)
    XCTAssertEqual(LineTimetable.make(from: []).departureCount, 0)
  }

  // MARK: - Fixtures

  private func departure(
    id: String,
    destination: String,
    minutes: Double,
    status: DepartureStatus = .onTime
  ) -> StationDeparture {
    StationDeparture(
      id: id,
      route: RouteBadge(
        id: RouteID(rawValue: "metro-4"),
        shortName: "4",
        mode: .metro,
        colorHex: "#B42C91",
        textColorHex: "#FFFFFF"
      ),
      destination: destination,
      scheduledAt: start.addingTimeInterval(minutes * 60),
      expectedAt: nil,
      delaySeconds: nil,
      status: status
    )
  }
}
