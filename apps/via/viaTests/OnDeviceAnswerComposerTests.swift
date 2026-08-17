import XCTest
@testable import Via

final class OnDeviceAnswerComposerTests: XCTestCase {
    func testDeterministicAnswerAlwaysUsesFrenchParisTime() throws {
        let facts = try makeFacts()

        let answer = OnDeviceAnswerComposer.deterministicAnswer(facts)

        XCTAssertEqual(
            answer,
            "De Châtelet à Nation : départ 10 h 05, arrivée 10 h 35 le lundi 17 août."
        )
    }

    func testVerifiedClaimsAcceptOnlyJourneyFacts() throws {
        let facts = try makeFacts()
        let output = GeneratedVerifiedAnswer(
            answer: "Prends le RER A de Châtelet à Nation : arrivée à 10 h 35.",
            claims: GeneratedAnswerClaims(
                places: ["Châtelet", "Nation"],
                lines: ["A"],
                times: [ISO8601.string(facts.journey.arrivalAt)],
                durationsSeconds: [],
                warnings: []
            )
        )

        XCTAssertTrue(OnDeviceAnswerComposer.validateAnswer(output, facts: facts))
    }

    func testInventedClaimsAreRejectedIndependently() throws {
        let facts = try makeFacts()
        let valid = GeneratedAnswerClaims(
            places: [],
            lines: [],
            times: [],
            durationsSeconds: [],
            warnings: []
        )

        XCTAssertFalse(OnDeviceAnswerComposer.validateAnswer(
            .init(answer: "Va à Opéra.", claims: .init(
                places: ["Opéra"], lines: [], times: [], durationsSeconds: [], warnings: []
            )),
            facts: facts
        ))
        XCTAssertFalse(OnDeviceAnswerComposer.validateAnswer(
            .init(answer: "Prends la ligne 13.", claims: .init(
                places: [], lines: ["13"], times: [], durationsSeconds: [], warnings: []
            )),
            facts: facts
        ))
        XCTAssertFalse(OnDeviceAnswerComposer.validateAnswer(
            .init(answer: "Pars plus tard.", claims: .init(
                places: [], lines: [], times: ["2026-08-17T12:00:00+02:00"], durationsSeconds: [], warnings: []
            )),
            facts: facts
        ))
        XCTAssertFalse(OnDeviceAnswerComposer.validateAnswer(
            .init(answer: "Le trajet dure une heure.", claims: .init(
                places: [], lines: [], times: [], durationsSeconds: [3_600], warnings: []
            )),
            facts: facts
        ))
        XCTAssertFalse(OnDeviceAnswerComposer.validateAnswer(
            .init(answer: "Attention.", claims: .init(
                places: [], lines: [], times: [], durationsSeconds: [], warnings: ["Travaux"]
            )),
            facts: facts
        ))
        XCTAssertTrue(OnDeviceAnswerComposer.validateAnswer(
            .init(answer: "Trajet vérifié.", claims: valid),
            facts: facts
        ))
    }

    func testUnclaimedLineTimeAndDisruptionLanguageAreRejected() throws {
        let facts = try makeFacts()
        let empty = GeneratedAnswerClaims(
            places: [], lines: [], times: [], durationsSeconds: [], warnings: []
        )

        XCTAssertFalse(OnDeviceAnswerComposer.validateAnswer(
            .init(answer: "Prends la ligne 13.", claims: empty),
            facts: facts
        ))
        XCTAssertFalse(OnDeviceAnswerComposer.validateAnswer(
            .init(answer: "Arrivée à 11 h 42.", claims: empty),
            facts: facts
        ))
        XCTAssertFalse(OnDeviceAnswerComposer.validateAnswer(
            .init(answer: "Tu éviteras tout retard.", claims: empty),
            facts: facts
        ))
    }

    private func makeFacts() throws -> OnDeviceAnswerFacts {
        let departure = try XCTUnwrap(ISO8601.parse("2026-08-17T10:05:00+02:00"))
        let arrival = try XCTUnwrap(ISO8601.parse("2026-08-17T10:35:00+02:00"))
        let origin = JourneyPlace(
            name: "Châtelet",
            coordinate: .init(latitude: 48.8583, longitude: 2.3470)
        )
        let destination = JourneyPlace(
            name: "Nation",
            coordinate: .init(latitude: 48.8484, longitude: 2.3958)
        )
        let route = JourneyRoute(
            id: .init(rawValue: "rer-a"),
            shortName: "A",
            longName: "RER A",
            mode: .rer,
            colorHex: "E3051C",
            textColorHex: "FFFFFF"
        )
        let section = JourneySection(
            id: "section",
            kind: .transit,
            durationSeconds: 1_800,
            from: origin,
            to: destination,
            departureAt: departure,
            arrivalAt: arrival,
            geometry: [origin.coordinate, destination.coordinate],
            route: route,
            direction: "Nation",
            platform: nil,
            stops: []
        )
        return OnDeviceAnswerFacts(
            originLabel: origin.name,
            destinationLabel: destination.name,
            requestedAt: arrival,
            datetimeRepresents: .arrival,
            journey: Journey(
                id: .init(rawValue: "journey"),
                qualifier: .recommended,
                durationSeconds: 1_800,
                walkingDurationSeconds: 0,
                transferCount: 0,
                departureAt: departure,
                arrivalAt: arrival,
                status: .normal,
                warnings: [],
                sections: [section]
            ),
            preferenceNotice: nil
        )
    }
}
