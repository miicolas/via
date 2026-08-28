import XCTest
@testable import Via

final class JourneyTimelineTests: XCTestCase {
    private let referenceDate = Date(timeIntervalSince1970: 2_000_000_000)

    func testEveryNodeCarriesAResolvedTimeWhenSectionsOmitTheirs() {
        // The planners frequently leave `departureAt` / `arrivalAt` nil on walk,
        // wait and transfer sections. The old timeline read those optionals
        // directly and displayed nothing.
        let journey = makeJourney()
        XCTAssertTrue(journey.sections.allSatisfy { $0.kind == .transit || $0.departureAt == nil })

        let nodes = JourneyTimeline.nodes(for: journey)

        XCTAssertFalse(nodes.isEmpty)
        for node in nodes {
            XCTAssertGreaterThanOrEqual(node.endsAt, node.startsAt, "\(node.id) ends before it starts")
        }
        XCTAssertEqual(nodes.first?.startsAt, journey.departureAt)
        XCTAssertEqual(nodes.last?.startsAt, journey.arrivalAt)
    }

    func testTimesIncreaseMonotonicallyDownTheTimeline() {
        let nodes = JourneyTimeline.nodes(for: makeJourney())

        for (previous, next) in zip(nodes, nodes.dropFirst()) {
            XCTAssertGreaterThanOrEqual(
                next.startsAt,
                previous.startsAt,
                "\(next.id) goes back in time after \(previous.id)"
            )
        }
    }

    func testBoardingAndAlightingComeFromTheStopListWithoutDuplication() {
        let nodes = JourneyTimeline.nodes(for: makeJourney())

        let boarding = nodes.compactMap { node -> JourneyStop? in
            guard case .board(let stop, _, _, _, _) = node.kind else { return nil }
            return stop
        }
        let alighting = nodes.compactMap { node -> JourneyStop? in
            guard case .alight(let stop, _) = node.kind else { return nil }
            return stop
        }

        XCTAssertEqual(boarding.map(\.name), ["Châtelet", "Gare de Lyon"])
        XCTAssertEqual(alighting.map(\.name), ["Gare de Lyon", "Vincennes"])
        // Four calls means two intermediate stops, not four extra rows.
        XCTAssertEqual(intermediateStops(in: nodes).map(\.name), ["Bastille", "Gare d'Austerlitz"])
    }

    func testBoardingTimeUsesTheStopTimetableRatherThanTheSectionCursor() {
        let nodes = JourneyTimeline.nodes(for: makeJourney())

        let boarding = nodes.first { if case .board = $0.kind { return true } else { return false } }
        let alighting = nodes.first { if case .alight = $0.kind { return true } else { return false } }

        XCTAssertEqual(boarding?.startsAt, referenceDate.addingTimeInterval(5 * 60))
        XCTAssertEqual(alighting?.startsAt, referenceDate.addingTimeInterval(17 * 60))
    }

    func testSectionWithoutStopsStillProducesBoardingAndAlightingNodes() {
        let nodes = JourneyTimeline.nodes(for: makeJourney())
        let secondLeg = nodes.filter { node in
            guard node.sectionID == "section:3" else { return false }
            switch node.kind {
            case .board, .alight: return true
            default: return false
            }
        }

        XCTAssertEqual(secondLeg.count, 2, "no stop list means no ride row")
        guard case .board(let stop, _, _, _, _) = secondLeg[0].kind else {
            return XCTFail("expected a boarding node")
        }
        XCTAssertEqual(stop.name, "Gare de Lyon")
        guard case .alight(let alightStop, _) = secondLeg[1].kind else {
            return XCTFail("expected an alighting node")
        }
        XCTAssertEqual(alightStop.name, "Vincennes")
    }

    func testRailFollowsTheLegBeingTravelledAcrossEachGap() {
        let nodes = JourneyTimeline.nodes(for: makeJourney())

        let walk = nodes.first { if case .walk = $0.kind { return true } else { return false } }
        XCTAssertEqual(walk?.railAbove, .pedestrian)
        // The gap between walking and boarding is still walking.
        XCTAssertEqual(walk?.railBelow, .pedestrian)

        let ride = nodes.first { if case .ride = $0.kind { return true } else { return false } }
        XCTAssertEqual(ride?.railAbove, .line(colorHex: "FFCE00"))
        XCTAssertEqual(ride?.railBelow, .line(colorHex: "FFCE00"))

        // After alighting the leg is over, so the gap belongs to the transfer.
        let firstAlight = nodes.first { if case .alight = $0.kind { return true } else { return false } }
        XCTAssertEqual(firstAlight?.railBelow, .pedestrian)
    }

    func testNoRailIsDrawnBetweenTwoNodesDescribingTheSamePlace() {
        let journey = makeJourney(startsWithWalk: false)
        let nodes = JourneyTimeline.nodes(for: journey)

        XCTAssertEqual(
            nodes.first?.railBelow,
            JourneyTimelineRailStyle.none,
            "origin and boarding share a place"
        )
        XCTAssertEqual(
            nodes.last?.railAbove,
            JourneyTimelineRailStyle.none,
            "alighting and destination share a place"
        )
    }

    func testTerminusBeadsSitAtBothEnds() {
        let nodes = JourneyTimeline.nodes(for: makeJourney())

        XCTAssertEqual(nodes.first?.bead, .terminus)
        XCTAssertEqual(nodes.last?.bead, .terminus)
        XCTAssertEqual(nodes.first?.railAbove, JourneyTimelineRailStyle.none)
        XCTAssertEqual(nodes.last?.railBelow, JourneyTimelineRailStyle.none)
    }

    func testPreviewJourneyWithTwoTransfersExposesEveryLeg() {
        let journey = Journey.mapPreviewMultipleTransfers
        let transitSectionIDs = journey.sections.filter { $0.kind == .transit }.map(\.id)

        let nodes = JourneyTimeline.nodes(for: journey)

        for sectionID in transitSectionIDs {
            let leg = nodes.filter { $0.sectionID == sectionID }
            XCTAssertTrue(
                leg.contains { if case .board = $0.kind { return true } else { return false } },
                "\(sectionID) has no boarding node"
            )
            XCTAssertTrue(
                leg.contains { if case .alight = $0.kind { return true } else { return false } },
                "\(sectionID) has no alighting node"
            )
        }
        XCTAssertEqual(nodes.last?.startsAt, journey.arrivalAt)
    }

    func testBoardingCarriesItsPositionAndAlightingItsExit() {
        let position = JourneyBoardingPosition(
            car: 5,
            carCount: 5,
            zone: .rear,
            reason: .exit,
            equipment: nil
        )
        let exit = JourneyExit(
            id: "IDFM:50147797",
            name: "pl. du Châtelet",
            number: 16,
            coordinate: GeoCoordinate(latitude: 48.8576, longitude: 2.3472),
            walkingMeters: 180
        )
        let journey = makeJourney(firstLegPosition: position, firstLegExit: exit)

        let nodes = JourneyTimeline.nodes(for: journey).filter { $0.sectionID == "section:1" }

        guard case .board(_, _, _, _, let boarded) = nodes.first?.kind else {
            return XCTFail("expected a boarding node")
        }
        guard case .alight(_, let alighted) = nodes.last?.kind else {
            return XCTFail("expected an alighting node")
        }
        XCTAssertEqual(boarded, position)
        XCTAssertEqual(alighted, exit)
    }

    func testALegWithoutWayfindingCarriesNeither() {
        // The destination node shares the last section's id, so match on the
        // node kind rather than on position within the leg.
        let nodes = JourneyTimeline.nodes(for: makeJourney()).filter { $0.sectionID == "section:3" }

        let boarded = nodes.compactMap { node -> JourneyBoardingPosition?? in
            guard case .board(_, _, _, _, let position) = node.kind else { return nil }
            return position
        }
        let alighted = nodes.compactMap { node -> JourneyExit?? in
            guard case .alight(_, let exit) = node.kind else { return nil }
            return exit
        }

        XCTAssertEqual(boarded.count, 1)
        XCTAssertEqual(alighted.count, 1)
        XCTAssertNil(boarded.first ?? nil)
        XCTAssertNil(alighted.first ?? nil)
    }

    func testDisplayedNodesHideOnlyZeroLengthMovementScaffolding() {
        let nodes = [
            displayNode(id: "origin", kind: .origin(name: "Opéra"), duration: 0),
            displayNode(id: "walk:zero", kind: .walk(destination: "Opéra"), duration: 0),
            displayNode(id: "wait:zero", kind: .wait(place: "Opéra"), duration: 0),
            displayNode(id: "transfer:zero", kind: .transfer(destination: "Opéra"), duration: 0),
            displayNode(id: "walk:real", kind: .walk(destination: "Quai"), duration: 60),
            displayNode(id: "destination", kind: .destination(name: "Bastille"), duration: 0),
        ]

        let displayed = nodes.filter(\.isTravellerInstruction)

        XCTAssertEqual(
            displayed.map(\.id),
            ["origin", "walk:real", "destination"]
        )
        XCTAssertEqual(nodes.count, 6, "the journey timeline remains unchanged")
    }

    func testBoardingPositionUsesTheThreeTrainCarSymbols() {
        let cases: [(JourneyBoardingPosition.Zone, String)] = [
            (.front, "train.side.front.car"),
            (.middle, "train.side.middle.car"),
            (.rear, "train.side.rear.car"),
        ]

        for (zone, expectedSymbol) in cases {
            let position = JourneyBoardingPosition(
                car: 5,
                carCount: 8,
                zone: zone,
                reason: .exit,
                equipment: nil
            )
            XCTAssertEqual(position.systemImage, expectedSymbol)
            XCTAssertEqual(position.carLabel, "5/8")
        }
    }

    func testJourneyActionSymbolsCoverEveryState() {
        XCTAssertEqual(JourneyActivationAction.go.title, "GO")
        XCTAssertEqual(JourneyActivationAction.goTitleVariants.count, 6)
        XCTAssertTrue(JourneyActivationAction.goTitleVariants.contains("GO"))
        XCTAssertTrue(JourneyActivationAction.goTitleVariants.contains(JourneyActivationAction.go.displayTitle))
        XCTAssertEqual(JourneyActivationAction.go.systemImage, "location.fill")
        XCTAssertEqual(JourneyActivationAction.plan.systemImage, "calendar.badge.plus")
        XCTAssertEqual(JourneyActivationAction.planned.systemImage, "calendar.badge.checkmark")
        XCTAssertEqual(JourneyActivationAction.resume.systemImage, "arrow.clockwise")
        XCTAssertEqual(JourneyActivationAction.active.systemImage, "checkmark")
        XCTAssertEqual(StateSymbol.bell(isOn: false), "bell")
        XCTAssertEqual(StateSymbol.bell(isOn: true), "bell.fill")
    }

    @MainActor
    func testCompactTransitSectionKeepsDeparturePenultimateAndTerminusVisible() {
        let sectionNodes = JourneyTimeline.nodes(for: makeJourney())
            .filter { $0.sectionID == "section:1" }

        let departure = sectionNodes.compactMap { node -> JourneyStop? in
            guard case .board(let stop, _, _, _, _) = node.kind else { return nil }
            return stop
        }.first
        let intermediate = sectionNodes.compactMap { node -> [JourneyStop]? in
            guard case .ride(let stops) = node.kind else { return nil }
            return stops
        }.first ?? []
        let terminus = sectionNodes.compactMap { node -> JourneyStop? in
            guard case .alight(let stop, _) = node.kind else { return nil }
            return stop
        }.first

        let compactStops = JourneyStopListView.displayedStops(
            from: intermediate,
            isExpanded: false
        )
        XCTAssertEqual(
            [departure?.name, compactStops.first?.name, terminus?.name].compactMap(\.self),
            ["Châtelet", "Gare d'Austerlitz", "Gare de Lyon"]
        )
        XCTAssertEqual(
            JourneyStopListView.displayedStops(from: intermediate, isExpanded: true).map(\.name),
            ["Bastille", "Gare d'Austerlitz"]
        )
    }

    // MARK: - Fixtures

    private func intermediateStops(in nodes: [JourneyTimelineNode]) -> [JourneyStop] {
        nodes.flatMap { node -> [JourneyStop] in
            guard case .ride(let intermediate) = node.kind else { return [] }
            return intermediate
        }
    }

    private func displayNode(
        id: String,
        kind: JourneyTimelineNode.Kind,
        duration: TimeInterval
    ) -> JourneyTimelineNode {
        JourneyTimelineNode(
            id: id,
            sectionID: "section:\(id)",
            sectionIndex: 0,
            kind: kind,
            startsAt: referenceDate,
            endsAt: referenceDate.addingTimeInterval(duration),
            railAbove: .pedestrian,
            railBelow: .pedestrian,
            bead: .none,
            mode: nil
        )
    }

    private func makeJourney(
        startsWithWalk: Bool = true,
        firstLegPosition: JourneyBoardingPosition? = nil,
        firstLegExit: JourneyExit? = nil
    ) -> Journey {
        let chatelet = JourneyPlace(
            name: "Châtelet",
            coordinate: GeoCoordinate(latitude: 48.8586, longitude: 2.3477)
        )
        let gareDeLyon = JourneyPlace(
            name: "Gare de Lyon",
            coordinate: GeoCoordinate(latitude: 48.8443, longitude: 2.3743)
        )
        let vincennes = JourneyPlace(
            name: "Vincennes",
            coordinate: GeoCoordinate(latitude: 48.8475, longitude: 2.4370)
        )

        let firstLeg = JourneySection(
            id: "section:1",
            kind: .transit,
            durationSeconds: 12 * 60,
            from: chatelet,
            to: gareDeLyon,
            departureAt: referenceDate.addingTimeInterval(5 * 60),
            arrivalAt: referenceDate.addingTimeInterval(17 * 60),
            geometry: [chatelet.coordinate, gareDeLyon.coordinate],
            route: JourneyRoute(
                id: RouteID(rawValue: "route:1"),
                shortName: "1",
                longName: "Métro 1",
                mode: .metro,
                colorHex: "FFCE00",
                textColorHex: "000000"
            ),
            direction: "Château de Vincennes",
            platform: "2",
            stops: [
                stop(id: "s1", place: chatelet, at: 5 * 60),
                stop(id: "s2", name: "Bastille", at: 9 * 60),
                stop(id: "s3", name: "Gare d'Austerlitz", at: 13 * 60),
                stop(id: "s4", place: gareDeLyon, at: 17 * 60),
            ],
            boardingPosition: firstLegPosition,
            exit: firstLegExit
        )

        let transfer = JourneySection(
            id: "section:2",
            kind: .transfer,
            durationSeconds: 3 * 60,
            from: gareDeLyon,
            to: gareDeLyon,
            departureAt: nil,
            arrivalAt: nil,
            geometry: [],
            route: nil,
            direction: nil,
            platform: nil,
            stops: []
        )

        let secondLeg = JourneySection(
            id: "section:3",
            kind: .transit,
            durationSeconds: 10 * 60,
            from: gareDeLyon,
            to: vincennes,
            departureAt: nil,
            arrivalAt: nil,
            geometry: [gareDeLyon.coordinate, vincennes.coordinate],
            route: JourneyRoute(
                id: RouteID(rawValue: "route:a"),
                shortName: "A",
                longName: "RER A",
                mode: .rer,
                colorHex: "E3051C",
                textColorHex: "FFFFFF"
            ),
            direction: "Boissy-Saint-Léger",
            platform: nil,
            stops: []
        )

        let walk = JourneySection(
            id: "section:0",
            kind: .walk,
            durationSeconds: 5 * 60,
            from: JourneyPlace(name: "Départ", coordinate: chatelet.coordinate),
            to: chatelet,
            departureAt: nil,
            arrivalAt: nil,
            geometry: [],
            route: nil,
            direction: nil,
            platform: nil,
            stops: []
        )

        let sections = startsWithWalk
            ? [walk, firstLeg, transfer, secondLeg]
            : [firstLeg, transfer, secondLeg]

        return Journey(
            id: JourneyID(rawValue: "test:journey"),
            qualifier: .recommended,
            durationSeconds: sections.reduce(0) { $0 + $1.durationSeconds },
            walkingDurationSeconds: startsWithWalk ? 5 * 60 : 0,
            transferCount: 1,
            departureAt: startsWithWalk ? referenceDate : referenceDate.addingTimeInterval(5 * 60),
            arrivalAt: referenceDate.addingTimeInterval(30 * 60),
            status: .normal,
            warnings: [],
            sections: sections
        )
    }

    private func stop(
        id: String,
        place: JourneyPlace? = nil,
        name: String? = nil,
        at offset: TimeInterval
    ) -> JourneyStop {
        JourneyStop(
            id: id,
            name: place?.name ?? name ?? id,
            coordinate: place?.coordinate ?? GeoCoordinate(latitude: 48.85, longitude: 2.36),
            arrivalAt: referenceDate.addingTimeInterval(offset),
            departureAt: referenceDate.addingTimeInterval(offset)
        )
    }
}
