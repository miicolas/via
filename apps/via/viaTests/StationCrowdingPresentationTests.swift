import Foundation
import SwiftUI
import XCTest

@testable import Via

final class StationCrowdingPresentationTests: XCTestCase {
  private var calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    return calendar
  }()

  private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }

  func testWeekRunsMondayToSundayAroundAMidweekDate() {
    // Wednesday 26 August 2026.
    let days = StationCrowdingPresentation.days(containing: date(2026, 8, 26), calendar: calendar)

    XCTAssertEqual(days.count, 7)
    XCTAssertEqual(days.map(\.index), Array(0..<7))
    XCTAssertEqual(
      days.map { calendar.component(.day, from: $0.date) },
      [24, 25, 26, 27, 28, 29, 30]
    )
    XCTAssertEqual(
      days.map(\.dayType),
      [.weekday, .weekday, .weekday, .weekday, .weekday, .saturday, .sunday]
    )
  }

  func testWeekIsMondayFirstWhateverTheTravellerFirstWeekday() {
    var sundayFirst = calendar
    sundayFirst.firstWeekday = 1

    // Sunday 30 August 2026 still belongs to the week starting Monday the 24th.
    let days = StationCrowdingPresentation.days(
      containing: date(2026, 8, 30),
      calendar: sundayFirst
    )

    XCTAssertEqual(calendar.component(.day, from: days[0].date), 24)
    XCTAssertEqual(days[6].dayType, .sunday)
  }

  func testDefaultIndexPointsAtToday() {
    XCTAssertEqual(
      StationCrowdingPresentation.defaultIndex(for: date(2026, 8, 24), calendar: calendar),
      0
    )
    XCTAssertEqual(
      StationCrowdingPresentation.defaultIndex(for: date(2026, 8, 26), calendar: calendar),
      2
    )
    XCTAssertEqual(
      StationCrowdingPresentation.defaultIndex(for: date(2026, 8, 29), calendar: calendar),
      5
    )
    XCTAssertEqual(
      StationCrowdingPresentation.defaultIndex(for: date(2026, 8, 30), calendar: calendar),
      6
    )
  }

  func testTitleSpellsTheDayInFrenchSentenceCase() {
    XCTAssertEqual(
      StationCrowdingPresentation.title(for: date(2026, 8, 26), calendar: calendar),
      "Mercredi 26 août"
    )
    XCTAssertEqual(
      StationCrowdingPresentation.title(for: date(2026, 8, 30), calendar: calendar),
      "Dimanche 30 août"
    )
  }

  func testAxisOnlyLabelsTheQuartersOfTheDay() {
    let labels = (0..<24).compactMap(StationCrowdingPresentation.axisLabel(for:))

    XCTAssertEqual(labels, ["0h", "6h", "12h", "18h"])
  }

  func testHoursFollowTheDayType() {
    let crowding = StationCrowding.preview

    XCTAssertEqual(
      StationCrowdingPresentation.hours(for: .weekday, in: crowding),
      crowding.weekday
    )
    XCTAssertEqual(
      StationCrowdingPresentation.hours(for: .saturday, in: crowding),
      crowding.saturday
    )
    XCTAssertEqual(
      StationCrowdingPresentation.hours(for: .sunday, in: crowding),
      crowding.sunday
    )
  }

  func testOnlyTheCurrentHourOfTodayTurnsRed() {
    XCTAssertEqual(
      StationCrowdingPresentation.barColor(hour: 8, isTodayPage: true, currentHour: 8),
      .red
    )
    XCTAssertNotEqual(
      StationCrowdingPresentation.barColor(hour: 9, isTodayPage: true, currentHour: 8),
      .red
    )
    XCTAssertNotEqual(
      StationCrowdingPresentation.barColor(hour: 8, isTodayPage: false, currentHour: 8),
      .red
    )
  }

  func testAccessibilitySummaryNamesThePeaksThenTheQuietTruth() {
    func hours(_ levels: [Int: PeakLevel]) -> [CrowdingHour] {
      (0..<24).map { hour in
        CrowdingHour(hour: hour, ratio: 0.2, level: levels[hour] ?? .off)
      }
    }

    XCTAssertEqual(
      StationCrowdingPresentation.accessibilitySummary(for: hours([8: .peak, 18: .peak])),
      "Affluence maximale vers 8 h et 18 h"
    )
    XCTAssertEqual(
      StationCrowdingPresentation.accessibilitySummary(for: hours([13: .moderate])),
      "Fréquentation soutenue vers 13 h"
    )
    XCTAssertEqual(
      StationCrowdingPresentation.accessibilitySummary(for: hours([:])),
      "Fréquentation faible toute la journée"
    )
  }
}
