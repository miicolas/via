import Foundation

extension SearchResponse {
    static let mapPreview = SearchResponse(
        results: [
            .station(StationSearchResult(
                id: StationID(rawValue: "preview:chatelet"),
                name: "Châtelet",
                coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470),
                routes: [
                    RouteBadge(
                        id: RouteID(rawValue: "preview:rer:A"),
                        shortName: "A",
                        mode: .rer,
                        colorHex: "E3051C",
                        textColorHex: "FFFFFF"
                    ),
                    RouteBadge(
                        id: RouteID(rawValue: "preview:metro:1"),
                        shortName: "1",
                        mode: .metro,
                        colorHex: "FFCD00",
                        textColorHex: "000000"
                    ),
                ],
                distanceMeters: 420
            )),
            .address(AddressSearchResult(
                id: "92062_8815_00001",
                name: "1 Parvis de la Défense",
                context: "92800 Puteaux",
                coordinate: GeoCoordinate(latitude: 48.8918, longitude: 2.2380),
                distanceMeters: 8_900
            )),
        ],
        addressSource: .ok
    )
}

extension JourneyResult {
    static let mapPreview: JourneyResult = {
        let now = Date.now
        return JourneyResult(
            status: .ready,
            source: .realtime,
            generatedAt: now,
            journeys: [
                previewJourney(
                    id: "recommended",
                    qualifier: .recommended,
                    departureAt: now.addingTimeInterval(180),
                    firstTransitSeconds: 900,
                    secondTransitSeconds: 1_500
                ),
                previewJourney(
                    id: "rapid",
                    qualifier: .rapid,
                    departureAt: now.addingTimeInterval(420),
                    firstTransitSeconds: 720,
                    secondTransitSeconds: 1_380
                ),
                previewJourney(
                    id: "comfort",
                    qualifier: .comfort,
                    departureAt: now.addingTimeInterval(600),
                    firstTransitSeconds: 1_020,
                    secondTransitSeconds: 1_440
                ),
                previewJourney(
                    id: "walking",
                    qualifier: .lessWalking,
                    departureAt: now.addingTimeInterval(780),
                    firstTransitSeconds: 1_080,
                    secondTransitSeconds: 1_620
                ),
            ]
        )
    }()
}

extension Journey {
    static let mapPreviewMultipleTransfers: Journey = {
        let base = JourneyResult.mapPreview.journeys[0]
        let transfer = base.sections[2]
        let extraTransfer = JourneySection(
            id: "preview:extra-transfer",
            kind: .transfer,
            durationSeconds: 120,
            from: transfer.from,
            to: transfer.to,
            departureAt: nil,
            arrivalAt: nil,
            geometry: [],
            route: nil,
            direction: nil,
            platform: nil,
            stops: []
        )
        let extraTransitSource = base.sections[1]
        let extraTransit = JourneySection(
            id: "preview:extra-transit",
            kind: .transit,
            durationSeconds: 600,
            from: extraTransitSource.from,
            to: extraTransitSource.to,
            departureAt: nil,
            arrivalAt: nil,
            geometry: extraTransitSource.geometry,
            route: extraTransitSource.route,
            direction: extraTransitSource.direction,
            platform: extraTransitSource.platform,
            stops: []
        )
        return Journey(
            id: JourneyID(rawValue: "preview:multiple-transfers"),
            qualifier: base.qualifier,
            durationSeconds: base.durationSeconds + 720,
            walkingDurationSeconds: base.walkingDurationSeconds,
            transferCount: 2,
            departureAt: base.departureAt,
            arrivalAt: base.arrivalAt.addingTimeInterval(720),
            status: .normal,
            warnings: [],
            sections: Array(base.sections.dropLast()) + [
                extraTransfer,
                extraTransit,
                base.sections.last!,
            ]
        )
    }()
}

private func previewJourney(
    id: String,
    qualifier: Journey.Qualifier,
    departureAt: Date,
    firstTransitSeconds: Int,
    secondTransitSeconds: Int
) -> Journey {
    let origin = JourneyPlace(
        name: "Hôtel de Ville",
        coordinate: GeoCoordinate(latitude: 48.8575, longitude: 2.3514)
    )
    let chatelet = JourneyPlace(
        name: "Châtelet–Les Halles",
        coordinate: GeoCoordinate(latitude: 48.8610, longitude: 2.3469)
    )
    let etoile = JourneyPlace(
        name: "Charles de Gaulle–Étoile",
        coordinate: GeoCoordinate(latitude: 48.8738, longitude: 2.2950)
    )
    let destination = JourneyPlace(
        name: "La Défense",
        coordinate: GeoCoordinate(latitude: 48.8918, longitude: 2.2380)
    )
    let walkStart = 240
    let transfer = 180
    let walkEnd = 300
    let duration = walkStart + firstTransitSeconds + transfer + secondTransitSeconds + walkEnd
    let rer = JourneyRoute(
        id: RouteID(rawValue: "preview:rer:A"),
        shortName: "A",
        longName: "RER A",
        mode: .rer,
        colorHex: "E3051C",
        textColorHex: "FFFFFF"
    )
    let metro = JourneyRoute(
        id: RouteID(rawValue: "preview:metro:1"),
        shortName: "1",
        longName: "Métro 1",
        mode: .metro,
        colorHex: "FFCD00",
        textColorHex: "000000"
    )

    return Journey(
        id: JourneyID(rawValue: id),
        qualifier: qualifier,
        durationSeconds: duration,
        walkingDurationSeconds: walkStart + walkEnd,
        transferCount: 1,
        departureAt: departureAt,
        arrivalAt: departureAt.addingTimeInterval(TimeInterval(duration)),
        status: .normal,
        warnings: [],
        sections: [
            JourneySection(
                id: "\(id):walk-start",
                kind: .walk,
                durationSeconds: walkStart,
                from: origin,
                to: chatelet,
                departureAt: departureAt,
                arrivalAt: departureAt.addingTimeInterval(TimeInterval(walkStart)),
                geometry: [origin.coordinate, chatelet.coordinate],
                route: nil,
                direction: nil,
                platform: nil,
                stops: []
            ),
            JourneySection(
                id: "\(id):rer",
                kind: .transit,
                durationSeconds: firstTransitSeconds,
                from: chatelet,
                to: etoile,
                departureAt: nil,
                arrivalAt: nil,
                geometry: [chatelet.coordinate, etoile.coordinate],
                route: rer,
                direction: "Saint-Germain-en-Laye",
                platform: "A",
                stops: []
            ),
            JourneySection(
                id: "\(id):transfer",
                kind: .transfer,
                durationSeconds: transfer,
                from: etoile,
                to: etoile,
                departureAt: nil,
                arrivalAt: nil,
                geometry: [],
                route: nil,
                direction: nil,
                platform: nil,
                stops: []
            ),
            JourneySection(
                id: "\(id):metro",
                kind: .transit,
                durationSeconds: secondTransitSeconds,
                from: etoile,
                to: destination,
                departureAt: nil,
                arrivalAt: nil,
                geometry: [etoile.coordinate, destination.coordinate],
                route: metro,
                direction: "La Défense",
                platform: "1",
                stops: []
            ),
            JourneySection(
                id: "\(id):walk-end",
                kind: .walk,
                durationSeconds: walkEnd,
                from: destination,
                to: destination,
                departureAt: nil,
                arrivalAt: departureAt.addingTimeInterval(TimeInterval(duration)),
                geometry: [],
                route: nil,
                direction: nil,
                platform: nil,
                stops: []
            ),
        ]
    )
}
