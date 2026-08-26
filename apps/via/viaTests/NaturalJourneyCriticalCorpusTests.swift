@testable import Via
import XCTest

final class NaturalJourneyCriticalCorpusTests: XCTestCase {
    private let now = ISO8601.parse("2026-08-26T18:00:00+02:00")!

    func testFrenchPlaceRoleAndTypoCorpusNeverInverts() async {
        await assertScenarios([
            .init("fr-home-from", "rentrez chez moi depuis Auber", "fr_FR", "query:Auber", "saved:home"),
            .init("fr-home-marker-typo", "rentre à la maison depui Auber", "fr_FR", "query:Auber", "saved:home"),
            .init("fr-two-typos", "ramenez-moi chez mois depuiss Gare du Nord", "fr_FR", "query:Gare du Nord", "saved:home"),
            .init("fr-work-from", "emmène moi au travail depuis Nation", "fr_FR", "query:Nation", "saved:work"),
            .init("fr-office-from", "retourne au bureau depuis Bastille", "fr_FR", "query:Bastille", "saved:work"),
            .init("fr-home-ellipse", "retour maison depuis République", "fr_FR", "query:République", "saved:home"),
            .init("fr-saved-origin", "va de chez moi vers Auber", "fr_FR", "saved:home", "query:Auber"),
            .init("fr-work-origin", "aller de mon bureau à Nation", "fr_FR", "saved:work", "query:Nation"),
            .init("fr-canonical-pair", "de Auber à Nation", "fr_FR", "query:Auber", "query:Nation"),
            .init("fr-destination-first", "allez vers Nation depuis Auber", "fr_FR", "query:Auber", "query:Nation"),
            .init("fr-hyphenated-destination-first", "emmène-moi à Nation depuis Auber", "fr_FR", "query:Auber", "query:Nation"),
            .init("fr-departure-verb", "pars de Auber à Nation", "fr_FR", "query:Auber", "query:Nation"),
            .init("fr-implicit-origin", "va à Nation", "fr_FR", "current", "query:Nation"),
            .init("fr-towards", "aller vers Bastille", "fr_FR", "current", "query:Bastille"),
            .init("fr-home-only", "rentre chez moi", "fr_FR", "current", "saved:home"),
            .init("fr-work-slang", "va au boulot", "fr_FR", "current", "saved:work"),
            .init("fr-explicit-current", "de ma position à Nation", "fr_FR", "current", "query:Nation"),
            .init("fr-custom-origin", "de Salle de sport à Nation", "fr_FR", "saved:gym", "query:Nation"),
            .init("fr-custom-destination", "va vers Salle de sport", "fr_FR", "current", "saved:gym"),
            .init("fr-aux", "emmenez-moi aux Invalides", "fr_FR", "current", "query:Invalides"),
        ])
    }

    func testEnglishPlaceRoleAndTypoCorpusNeverInverts() async {
        await assertScenarios([
            .init("en-home-from", "get me home from Auber", "en_US", "query:Auber", "saved:home"),
            .init("en-work-from", "take me to work from Nation", "en_US", "query:Nation", "saved:work"),
            .init("en-return-home", "return home from Auber", "en_US", "query:Auber", "saved:home"),
            .init("en-canonical", "go from Auber to Nation", "en_US", "query:Auber", "query:Nation"),
            .init("en-towards", "take me from Auber towards Nation", "en_US", "query:Auber", "query:Nation"),
            .init("en-destination-first", "take me to Nation from Auber", "en_US", "query:Auber", "query:Nation"),
            .init("en-saved-origin", "from home to Auber", "en_US", "saved:home", "query:Auber"),
            .init("en-marker-typo", "frm Auber to Nation", "en_US", "query:Auber", "query:Nation"),
            .init("en-implicit-origin", "go to Nation", "en_US", "current", "query:Nation"),
            .init("en-office", "take me to the office", "en_US", "current", "saved:work"),
            .init("en-custom-origin", "from Salle de sport to Nation", "en_US", "saved:gym", "query:Nation"),
            .init("en-custom-destination", "go to Salle de sport", "en_US", "current", "saved:gym"),
            .init("en-politeness", "please get me home from Auber", "en_US", "query:Auber", "saved:home"),
        ])
    }

    func testExplicitModeAndLastServiceCorpusKeepsEveryConstraint() async {
        await assertScenarios([
            .init(
                "fr-only-metro", "de Auber à Nation uniquement en métro", "fr_FR",
                "query:Auber", "query:Nation", required: [.metro]
            ),
            .init(
                "fr-without-rer", "de Auber à Nation sans prendre le RER", "fr_FR",
                "query:Auber", "query:Nation", excluded: [.rer]
            ),
            .init(
                "fr-prefer-bus", "de Auber à Nation plutôt en bus", "fr_FR",
                "query:Auber", "query:Nation", preferred: [.bus]
            ),
            .init(
                "en-only-metro", "from Auber to Nation only by metro", "en_US",
                "query:Auber", "query:Nation", required: [.metro]
            ),
            .init(
                "en-without-rer", "from Auber to Nation without the RER", "en_US",
                "query:Auber", "query:Nation", excluded: [.rer]
            ),
            .init(
                "en-prefer-bus", "from Auber to Nation prefer bus", "en_US",
                "query:Auber", "query:Nation", preferred: [.bus]
            ),
            .init(
                "fr-last-service", "dernier train pour rentrer chez moi depuis Auber", "fr_FR",
                "query:Auber", "saved:home", timeAnchor: .lastOfDay
            ),
            .init(
                "en-last-service", "last train home from Auber", "en_US",
                "query:Auber", "saved:home", timeAnchor: .lastOfDay
            ),
            .init(
                "fr-bare-destination-conflicting-bus",
                "Nation plutôt en bus mais sans bus", "fr_FR",
                "current", "query:Nation", excluded: [.bus], preferred: [.bus]
            ),
            .init(
                "en-bare-destination-conflicting-bus",
                "Nation prefer bus but without bus", "en_US",
                "current", "query:Nation", excluded: [.bus], preferred: [.bus]
            ),
        ])
    }

    func testDestinationFirstWorkRequestKeepsNationAsOrigin() async throws {
        let transition = try await makeUnderstanding().interpret(
            NaturalJourneyTurn(
                phrase: "emmène moi au travail depuis Nation",
                locale: Locale(identifier: "fr_FR"),
                now: now,
            ),
            state: nil,
        )

        XCTAssertEqual(placeID(transition.state.intent.originPlace), "query:Nation")
        XCTAssertEqual(placeID(transition.state.intent.destinationPlace), "saved:work")
        XCTAssertEqual(transition.state.processingPath, .deterministic)
        XCTAssertTrue(transition.conflicts.isEmpty)
    }

    func testHyphenatedWorkCommandAlsoBypassesUnavailableModels() async throws {
        let transition = try await makeUnderstanding().interpret(
            NaturalJourneyTurn(
                phrase: "emmène-moi au travail depuis Nation",
                locale: Locale(identifier: "fr_FR"),
                now: now,
            ),
            state: nil,
        )

        XCTAssertEqual(placeID(transition.state.intent.originPlace), "query:Nation")
        XCTAssertEqual(placeID(transition.state.intent.destinationPlace), "saved:work")
        XCTAssertEqual(transition.state.processingPath, .deterministic)
    }

    func testExplicitOriginCorrectionChangesOnlyOriginWithoutAModel() async throws {
        let previous = confirmedState(origin: "Auber", destination: "Nation")

        let transition = try await makeUnderstanding().interpret(
            NaturalJourneyTurn(
                phrase: "non, depuis Opéra",
                locale: Locale(identifier: "fr_FR"),
                now: now,
            ),
            state: previous,
        )

        XCTAssertEqual(placeID(transition.state.intent.originPlace), "query:Opéra")
        XCTAssertEqual(placeID(transition.state.intent.destinationPlace), "query:Nation")
        XCTAssertEqual(transition.changedFields, [.origin])
        XCTAssertTrue(transition.conflicts.isEmpty)
    }

    func testNamedPreviousDestinationSurvivesAnOriginCorrection() async throws {
        let previous = confirmedState(origin: "Auber", destination: "Nation")

        let transition = try await makeUnderstanding().interpret(
            NaturalJourneyTurn(
                phrase: "même destination depuis Bastille",
                locale: Locale(identifier: "fr_FR"),
                now: now,
            ),
            state: previous,
        )

        XCTAssertEqual(placeID(transition.state.intent.originPlace), "query:Bastille")
        XCTAssertEqual(placeID(transition.state.intent.destinationPlace), "query:Nation")
        XCTAssertEqual(transition.changedFields, [.origin])
        XCTAssertTrue(transition.conflicts.isEmpty)
    }

    private func makeUnderstanding() -> ReliableNaturalJourneyUnderstanding {
        ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            savedPlaces: { Self.savedPlaces },
            serverFallbackAllowed: { true },
        )
    }

    private func assertScenarios(
        _ scenarios: [Scenario],
        file: StaticString = #filePath,
        line: UInt = #line,
    ) async {
        for scenario in scenarios {
            do {
                let transition = try await makeUnderstanding().interpret(
                    NaturalJourneyTurn(
                        phrase: scenario.phrase,
                        locale: Locale(identifier: scenario.locale),
                        now: now,
                    ),
                    state: nil,
                )
                let intent = transition.state.intent
                XCTAssertEqual(
                    placeID(intent.originPlace), scenario.origin,
                    "\(scenario.id): origine inversée pour « \(scenario.phrase) »",
                    file: file, line: line
                )
                XCTAssertEqual(
                    placeID(intent.destinationPlace), scenario.destination,
                    "\(scenario.id): destination inversée pour « \(scenario.phrase) »",
                    file: file, line: line
                )
                XCTAssertEqual(intent.requiredModes, scenario.required, scenario.id, file: file, line: line)
                XCTAssertEqual(intent.excludedModes, scenario.excluded, scenario.id, file: file, line: line)
                XCTAssertEqual(intent.preferredModes, scenario.preferred, scenario.id, file: file, line: line)
                XCTAssertEqual(intent.timeAnchor, scenario.timeAnchor, scenario.id, file: file, line: line)
                XCTAssertEqual(
                    transition.state.processingPath, .deterministic,
                    "\(scenario.id): un modèle a été appelé malgré une phrase complètement fondée",
                    file: file, line: line
                )
                XCTAssertTrue(transition.conflicts.isEmpty, scenario.id, file: file, line: line)
            } catch {
                XCTFail(
                    "\(scenario.id): « \(scenario.phrase) » a échoué avec \(error)",
                    file: file,
                    line: line,
                )
            }
        }
    }

    private func confirmedState(
        origin: String,
        destination: String,
    ) -> NaturalJourneyDialogueState {
        var state = NaturalJourneyDialogueState(intent: RouteIntent(
            scope: .journey,
            originPlace: .query(origin),
            destinationPlace: .query(destination),
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
        ))
        state[field: .origin] = .confirmed(evidence: origin)
        state[field: .destination] = .confirmed(evidence: destination)
        return state
    }

    private func placeID(_ place: RoutePlaceIntent?) -> String {
        switch place {
        case .currentLocation: "current"
        case .saved(let place): "saved:\(place.id)"
        case .query(let query): "query:\(query)"
        case .reference(let reference): "reference:\(reference.rawValue)"
        case nil: "none"
        }
    }

    private static let savedPlaces = [
        NaturalJourneySavedPlaceReference(
            id: "home",
            label: "Maison",
            kind: .home,
            result: .previewAddress,
        ),
        NaturalJourneySavedPlaceReference(
            id: "work",
            label: "Travail",
            kind: .work,
            result: .previewAddress,
        ),
        NaturalJourneySavedPlaceReference(
            id: "gym",
            label: "Salle de sport",
            kind: .custom,
            result: .previewAddress,
        ),
    ]

    private struct Scenario {
        let id: String
        let phrase: String
        let locale: String
        let origin: String
        let destination: String
        var required: Set<TransitMode> = []
        var excluded: Set<TransitMode> = []
        var preferred: Set<TransitMode> = []
        var timeAnchor: JourneyTimeAnchor?

        init(
            _ id: String,
            _ phrase: String,
            _ locale: String,
            _ origin: String,
            _ destination: String,
            required: Set<TransitMode> = [],
            excluded: Set<TransitMode> = [],
            preferred: Set<TransitMode> = [],
            timeAnchor: JourneyTimeAnchor? = nil,
        ) {
            self.id = id
            self.phrase = phrase
            self.locale = locale
            self.origin = origin
            self.destination = destination
            self.required = required
            self.excluded = excluded
            self.preferred = preferred
            self.timeAnchor = timeAnchor
        }
    }
}
