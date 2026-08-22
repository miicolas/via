import Foundation

/// Fixture-first source for the Lines tab: previews and the no-configuration
/// fallback both run on it.
struct PreviewLineStatusRepository: LineStatusRepository {
    let board: LineStatusBoard
    let details: [RouteID: LineDetail]

    init(
        board: LineStatusBoard = Self.defaultBoard,
        details: [RouteID: LineDetail] = [
            Self.metro1.id: Self.metro1Detail,
            Self.rerA.id: Self.rerADetail,
        ]
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
    static let rerA = route("IDFM:C01742", "A", .rer, "#E2231A")

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

    private static let metro1Stops = [
        LineSchemaStop(id: "IDFM:71264", name: "La Défense"),
        LineSchemaStop(id: "IDFM:71253", name: "Esplanade de la Défense"),
        LineSchemaStop(id: "IDFM:71217", name: "Charles de Gaulle — Étoile"),
        LineSchemaStop(id: "IDFM:71199", name: "Franklin D. Roosevelt"),
        LineSchemaStop(id: "IDFM:71167", name: "Concorde"),
        LineSchemaStop(id: "IDFM:71150", name: "Châtelet"),
        LineSchemaStop(id: "IDFM:71135", name: "Nation"),
        LineSchemaStop(id: "IDFM:71125", name: "Château de Vincennes"),
    ]

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
        directions: [
            LineDirection(
                id: "direction-0",
                directionId: 0,
                label: "Château de Vincennes",
                sections: [
                    LineSchemaSection(
                        role: .trunk,
                        label: nil,
                        origins: ["IDFM:71264"],
                        termini: ["IDFM:71125"],
                        stops: metro1Stops
                    )
                ]
            ),
            LineDirection(
                id: "direction-1",
                directionId: 1,
                label: "La Défense",
                sections: [
                    LineSchemaSection(
                        role: .trunk,
                        label: nil,
                        origins: ["IDFM:71125"],
                        termini: ["IDFM:71264"],
                        stops: metro1Stops.reversed()
                    )
                ]
            ),
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

    private static func schemaStop(_ id: String, _ name: String) -> LineSchemaStop {
        LineSchemaStop(id: id, name: name)
    }

    /// A branched line with a shared sub-trunk, the shape the schema exists for.
    static let rerADetail = LineDetail(
        route: rerA,
        branches: [],
        directions: [
            LineDirection(
                id: "direction-0",
                directionId: 0,
                label: "Marne-la-Vallée – Chessy / Boissy-St-Léger",
                sections: [
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Saint-Germain-en-Laye",
                        origins: ["IDFM:73618"],
                        termini: ["IDFM:74001", "IDFM:70648"],
                        stops: [
                            schemaStop("IDFM:73618", "Saint-Germain-en-Laye"),
                            schemaStop("IDFM:73620", "Le Vésinet — Le Pecq"),
                        ]
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Cergy-le-Haut",
                        origins: ["IDFM:73731"],
                        termini: ["IDFM:74001", "IDFM:70648"],
                        stops: [
                            schemaStop("IDFM:73731", "Cergy-le-Haut"),
                            schemaStop("IDFM:73733", "Conflans-Fin-d'Oise"),
                        ]
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Poissy",
                        origins: ["IDFM:73699"],
                        termini: ["IDFM:74001", "IDFM:70648"],
                        stops: [
                            schemaStop("IDFM:73699", "Poissy"),
                            schemaStop("IDFM:73697", "Achères-Ville"),
                        ]
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branches Cergy-le-Haut / Poissy",
                        origins: ["IDFM:73731", "IDFM:73699"],
                        termini: ["IDFM:74001", "IDFM:70648"],
                        stops: [
                            schemaStop("IDFM:73688", "Sartrouville"),
                            schemaStop("IDFM:73690", "Maisons-Laffitte"),
                        ]
                    ),
                    LineSchemaSection(
                        role: .trunk,
                        label: nil,
                        origins: ["IDFM:73618", "IDFM:73731", "IDFM:73699"],
                        termini: ["IDFM:74001", "IDFM:70648"],
                        stops: [
                            schemaStop("IDFM:71517", "Nanterre-Préfecture"),
                            schemaStop("IDFM:71264", "La Défense"),
                            schemaStop("IDFM:71304", "Auber"),
                            schemaStop("IDFM:71150", "Châtelet — Les Halles"),
                            schemaStop("IDFM:71270", "Gare de Lyon"),
                            schemaStop("IDFM:71135", "Nation"),
                            schemaStop("IDFM:71129", "Vincennes"),
                        ]
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Marne-la-Vallée – Chessy",
                        origins: ["IDFM:73618", "IDFM:73731", "IDFM:73699"],
                        termini: ["IDFM:74001"],
                        stops: [
                            schemaStop("IDFM:73942", "Val de Fontenay"),
                            schemaStop("IDFM:73952", "Noisy-le-Grand — Mont d'Est"),
                            schemaStop("IDFM:73963", "Val d'Europe"),
                            schemaStop("IDFM:74001", "Marne-la-Vallée – Chessy"),
                        ]
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Boissy-St-Léger",
                        origins: ["IDFM:73618", "IDFM:73731", "IDFM:73699"],
                        termini: ["IDFM:70648"],
                        stops: [
                            schemaStop("IDFM:70645", "Joinville-le-Pont"),
                            schemaStop("IDFM:70648", "Boissy-St-Léger"),
                        ]
                    ),
                ]
            ),
            LineDirection(
                id: "direction-1",
                directionId: 1,
                label: "Saint-Germain-en-Laye / Cergy-le-Haut / Poissy",
                sections: [
                    LineSchemaSection(
                        role: .trunk,
                        label: nil,
                        origins: ["IDFM:74001", "IDFM:70648"],
                        termini: ["IDFM:73618", "IDFM:73731", "IDFM:73699"],
                        stops: [
                            schemaStop("IDFM:71129", "Vincennes"),
                            schemaStop("IDFM:71135", "Nation"),
                            schemaStop("IDFM:71270", "Gare de Lyon"),
                            schemaStop("IDFM:71150", "Châtelet — Les Halles"),
                            schemaStop("IDFM:71304", "Auber"),
                            schemaStop("IDFM:71264", "La Défense"),
                            schemaStop("IDFM:71517", "Nanterre-Préfecture"),
                        ]
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Saint-Germain-en-Laye",
                        origins: ["IDFM:74001", "IDFM:70648"],
                        termini: ["IDFM:73618"],
                        stops: [
                            schemaStop("IDFM:73620", "Le Vésinet — Le Pecq"),
                            schemaStop("IDFM:73618", "Saint-Germain-en-Laye"),
                        ]
                    ),
                ]
            ),
        ],
        source: .live,
        fetchedAt: Date(timeIntervalSince1970: 1_755_500_000),
        disruptions: [
            LineDisruption(
                id: "d-rer-block",
                condition: .suspended,
                isActive: true,
                cause: "perturbation",
                title: "Trafic interrompu entre Noisy-le-Grand et Marne-la-Vallée",
                message: "Reprise estimée à 12 h.",
                periods: [
                    LineDisruptionPeriod(
                        beginsAt: Date(timeIntervalSince1970: 1_755_490_000),
                        endsAt: Date(timeIntervalSince1970: 1_755_530_000)
                    )
                ],
                impactedSections: [
                    LineImpactedSection(
                        fromStopID: "IDFM:73952",
                        fromName: "Noisy-le-Grand — Mont d'Est",
                        toStopID: "IDFM:74001",
                        toName: "Marne-la-Vallée – Chessy"
                    )
                ],
                updatedAt: Date(timeIntervalSince1970: 1_755_499_000)
            ),
            LineDisruption(
                id: "d-rer-slow",
                condition: .attention,
                isActive: true,
                cause: "perturbation",
                title: "Ralentissements entre Auber et Gare de Lyon",
                message: "Temps de parcours allongé de 10 minutes.",
                periods: [
                    LineDisruptionPeriod(
                        beginsAt: Date(timeIntervalSince1970: 1_755_490_000),
                        endsAt: Date(timeIntervalSince1970: 1_755_530_000)
                    )
                ],
                impactedSections: [
                    LineImpactedSection(
                        fromStopID: "IDFM:71304",
                        fromName: "Auber",
                        toStopID: "IDFM:71270",
                        toName: "Gare de Lyon"
                    )
                ],
                updatedAt: nil
            ),
        ]
    )
}
