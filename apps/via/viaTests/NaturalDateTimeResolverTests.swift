import FoundationModels
@testable import Via
import XCTest

final class NaturalDateTimeResolverTests: XCTestCase {
    private let now = ISO8601.parse("2026-08-17T09:00:00+02:00")!

    func testFoundationModelsPolicyUsesFrenchLocaleAndDeterministicSampling() {
        XCTAssertTrue(
            FoundationModelsIntentParser.instructions.hasPrefix(
                "The person's locale is fr_FR."
            )
        )
        XCTAssertFalse(FoundationModelsIntentParser.instructions.contains("Instant actuel:"))
        XCTAssertTrue(
            FoundationModelsIntentParser.instructions.contains(
                "DO NOT call any tools to fulfil the request."
            )
        )
        #if compiler(>=6.4)
            let expectedOptions = GenerationOptions(samplingMode: .greedy)
        #else
            let expectedOptions = GenerationOptions(sampling: .greedy)
        #endif
        XCTAssertEqual(
            FoundationModelsIntentParser.generationOptions,
            expectedOptions
        )
    }

    func testImplicitTimeUsesTodayInParis() throws {
        let result = try NaturalDateTimeResolver.resolve(
            parts(reference: .implicitToday, timePrecision: .exact, hour: 18),
            now: now
        )

        XCTAssertEqual(result.date, ISO8601.parse("2026-08-17T18:00:00+02:00"))
        XCTAssertFalse(result.dateWasExplicit)
        XCTAssertTrue(result.timeWasExplicit)
    }

    func testExplicitClockTimeOverridesAnIncorrectPartOfDayClassification() throws {
        let generatedParts = parts(
            reference: .implicitToday,
            timePrecision: .afternoon
        )

        let correctedParts = generatedParts.correctingSingleExactTime(
            in: "De Nation à La Défense après 18h"
        )
        let result = try NaturalDateTimeResolver.resolve(correctedParts, now: now)

        XCTAssertEqual(result.date, ISO8601.parse("2026-08-17T18:00:00+02:00"))
        XCTAssertTrue(result.timeWasExplicit)
    }

    func testExplicitClockTimeCorrectionKeepsMinutes() throws {
        let generatedParts = parts(
            reference: .tomorrow,
            timePrecision: .evening
        )

        let correctedParts = generatedParts.correctingSingleExactTime(
            in: "Partir vers La Défense après 18 h 30"
        )
        let result = try NaturalDateTimeResolver.resolve(correctedParts, now: now)

        XCTAssertEqual(result.date, ISO8601.parse("2026-08-18T18:30:00+02:00"))
    }

    func testRelativeDurationIsNotReinterpretedAsAClockTime() {
        let generatedParts = parts(
            reference: .relative,
            timePrecision: .unspecified,
            relativeAmount: 2,
            relativeUnit: .hour
        )

        let correctedParts = generatedParts.correctingSingleExactTime(
            in: "Partir vers La Défense dans 2 h"
        )

        XCTAssertEqual(correctedParts, generatedParts)
    }

    func testTwoClockTimesRemainAssignedByTheStructuredModel() {
        let generatedParts = parts(
            reference: .tomorrow,
            timePrecision: .afternoon
        )

        let correctedParts = generatedParts.correctingSingleExactTime(
            in: "Partir après 18 h et arriver avant 19 h à La Défense"
        )

        XCTAssertEqual(correctedParts, generatedParts)
    }

    func testTomorrowIsCalculatedWithoutAskingTheModelForAnISODate() throws {
        let result = try NaturalDateTimeResolver.resolve(
            parts(reference: .tomorrow, timePrecision: .exact, hour: 10),
            now: now
        )

        XCTAssertEqual(result.date, ISO8601.parse("2026-08-18T10:00:00+02:00"))
        XCTAssertTrue(result.dateWasExplicit)
        XCTAssertTrue(result.timeWasExplicit)
    }

    func testNextWeekdayIsCalculatedInParis() throws {
        let result = try NaturalDateTimeResolver.resolve(
            parts(reference: .friday, timePrecision: .exact, hour: 17),
            now: now
        )

        XCTAssertEqual(result.date, ISO8601.parse("2026-08-21T17:00:00+02:00"))
    }

    func testRelativeDurationUsesDeterministicCalendarMath() throws {
        let result = try NaturalDateTimeResolver.resolve(
            parts(reference: .relative, relativeAmount: 45, relativeUnit: .minute),
            now: now
        )

        XCTAssertEqual(result.date, ISO8601.parse("2026-08-17T09:45:00+02:00"))
        XCTAssertFalse(result.dateWasExplicit)
        XCTAssertTrue(result.timeWasExplicit)
    }

    func testDateWithoutTimeKeepsTheDayAndRequestsClarification() throws {
        let result = try NaturalDateTimeResolver.resolve(
            parts(reference: .tomorrow),
            now: now
        )

        XCTAssertEqual(result.date, ISO8601.parse("2026-08-18T12:00:00+02:00"))
        XCTAssertTrue(result.dateWasExplicit)
        XCTAssertFalse(result.timeWasExplicit)
    }

    func testCalendarDateRejectsImpossibleDay() {
        XCTAssertThrowsError(try NaturalDateTimeResolver.resolve(
            parts(reference: .calendarDate, year: 2026, month: 2, day: 31),
            now: now
        ))
    }

    func testTomorrowAcrossDaylightSavingUsesParisCivilTime() throws {
        let beforeDST = try XCTUnwrap(ISO8601.parse("2026-03-28T09:00:00+01:00"))
        let result = try NaturalDateTimeResolver.resolve(
            parts(reference: .tomorrow, timePrecision: .exact, hour: 9),
            now: beforeDST
        )

        XCTAssertEqual(result.date, ISO8601.parse("2026-03-29T09:00:00+02:00"))
    }

    private func parts(
        reference: NaturalDateReference,
        year: Int = 2026,
        month: Int = 1,
        day: Int = 1,
        timePrecision: NaturalTimePrecision = .unspecified,
        hour: Int = 0,
        minute: Int = 0,
        relativeAmount: Int = 0,
        relativeUnit: NaturalRelativeUnit = .minute
    ) -> NaturalDateTimeParts {
        NaturalDateTimeParts(
            reference: reference,
            year: year,
            yearWasExplicit: true,
            month: month,
            day: day,
            timePrecision: timePrecision,
            hour: hour,
            minute: minute,
            relativeAmount: relativeAmount,
            relativeUnit: relativeUnit
        )
    }
}
