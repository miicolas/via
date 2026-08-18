import Foundation

/// Fixture-first source for the Lines tab: previews and the no-configuration
/// fallback both run on it.
struct PreviewLineStatusRepository: LineStatusRepository {
    let board: LineStatusBoard
    let details: [RouteID: LineDetail]

    init(
        board: LineStatusBoard = Self.defaultBoard,
        details: [RouteID: LineDetail] = [Self.metro1.id: Self.metro1Detail]
    ) {
        self.board = board
        self.details = details
    }

    func statuses() async throws -> LineStatusBoard {
        board
    }

    func searchLines(query: String) async throws -> LineStatusBoard {
        LineStatusBoard(
            source: board.source,
            fetchedAt: board.fetchedAt,
            lines: board.lines.filter { $0.matchesSearch(query) }
        )
    }

    func detail(lineID: RouteID) async throws -> LineDetail {
        guard let detail = details[lineID] else { throw ViaError.unavailable }
        return detail
    }

    private static func route(
        _ id: String,
        _ shortName: String,
        _ mode: TransitMode,
        _ colorHex: String,
        textColorHex: String = "#FFFFFF"
    ) -> RouteBadge {
        RouteBadge(
            id: RouteID(rawValue: id),
            shortName: shortName,
            mode: mode,
            colorHex: colorHex,
            textColorHex: textColorHex
        )
    }

    static let metro1 = route("IDFM:C01371", "1", .metro, "#FFCD00", textColorHex: "#000000")

    static let defaultBoard = LineStatusBoard(
        source: .live,
        fetchedAt: Date(timeIntervalSince1970: 1_755_500_000),
        lines: [
            LineStatus(
                route: metro1,
                condition: .suspended,
                summary: "Trafic interrompu entre La Défense et Nation.",
                activeCount: 1,
                upcoming: nil
            ),
            LineStatus(
                route: route("IDFM:C01374", "4", .metro, "#B42C91"),
                condition: .disrupted,
                summary: "Trafic perturbé entre Châtelet et Gare du Nord.",
                activeCount: 2,
                upcoming: nil
            ),
            LineStatus(
                route: route("IDFM:C01384", "14", .metro, "#62259D"),
                condition: .normal,
                summary: nil,
                activeCount: 0,
                upcoming: UpcomingClosure(
                    beginsAt: Date(timeIntervalSince1970: 1_755_540_000),
                    title: "Fermeture à 22 h pour travaux"
                )
            ),
            LineStatus(
                route: route("IDFM:C01743", "B", .rer, "#5291CE"),
                condition: .attention,
                summary: "Des ralentissements sont à prévoir ce matin.",
                activeCount: 1,
                upcoming: nil
            ),
            LineStatus(
                route: route("IDFM:C01739", "L", .transilien, "#7584BC"),
                condition: .normal,
                summary: nil,
                activeCount: 0,
                upcoming: nil
            ),
            LineStatus(
                route: route("IDFM:C01390", "T3a", .tram, "#FF7F00"),
                condition: .normal,
                summary: nil,
                activeCount: 0,
                upcoming: nil
            ),
        ]
    )

    static let metro1Detail = LineDetail(
        route: metro1,
        branches: [
            LineBranch(
                id: "p-m1-0",
                directionId: 0,
                headsign: "Château de Vincennes",
                isCanonical: true,
                stops: [
                    LineStop(id: "IDFM:71264", name: "La Défense"),
                    LineStop(id: "IDFM:71253", name: "Esplanade de la Défense"),
                    LineStop(id: "IDFM:71217", name: "Charles de Gaulle — Étoile"),
                    LineStop(id: "IDFM:71199", name: "Franklin D. Roosevelt"),
                    LineStop(id: "IDFM:71167", name: "Concorde"),
                    LineStop(id: "IDFM:71150", name: "Châtelet"),
                    LineStop(id: "IDFM:71135", name: "Nation"),
                    LineStop(id: "IDFM:71125", name: "Château de Vincennes"),
                ]
            )
        ],
        source: .live,
        fetchedAt: Date(timeIntervalSince1970: 1_755_500_000),
        disruptions: [
            LineDisruption(
                id: "d-block",
                condition: .suspended,
                isActive: true,
                cause: "perturbation",
                title: "Trafic interrompu entre La Défense et Nation",
                message: "En raison d’un incident d’exploitation, le trafic est interrompu. "
                    + "Reprise estimée à 18 h.",
                periods: [
                    LineDisruptionPeriod(
                        beginsAt: Date(timeIntervalSince1970: 1_755_490_000),
                        endsAt: Date(timeIntervalSince1970: 1_755_530_000)
                    )
                ],
                impactedSections: [
                    LineImpactedSection(
                        fromStopID: "IDFM:71264",
                        fromName: "La Défense",
                        toStopID: "IDFM:71135",
                        toName: "Nation"
                    )
                ],
                updatedAt: Date(timeIntervalSince1970: 1_755_499_000)
            ),
            LineDisruption(
                id: "d-works",
                condition: .attention,
                isActive: false,
                cause: "travaux",
                title: "Fermeture en soirée la semaine prochaine",
                message: "La station Concorde fermera à partir de 22 h.",
                periods: [
                    LineDisruptionPeriod(
                        beginsAt: Date(timeIntervalSince1970: 1_755_540_000),
                        endsAt: Date(timeIntervalSince1970: 1_755_550_000)
                    )
                ],
                impactedSections: [],
                updatedAt: nil
            ),
        ]
    )
}
