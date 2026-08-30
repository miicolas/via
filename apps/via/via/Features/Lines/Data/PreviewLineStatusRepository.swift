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

    private static func schemaStop(
        _ id: String,
        _ name: String,
        interchange: Bool = false
    ) -> LineSchemaStop {
        LineSchemaStop(id: id, name: name, isInterchange: interchange)
    }

    // The January 2026 RATP/IDFM plan, kept complete so previews exercise the
    // same 46-station topology travellers see on platforms. Arrays are stored
    // east-to-west; the opposite direction reverses them without inventing a
    // second version of the line.
    private static let rerABoissyBranch = [
        schemaStop("IDFM:72881", "Boissy-Saint-Léger"),
        schemaStop("IDFM:72929", "Sucy - Bonneuil"),
        schemaStop("IDFM:72998", "La Varenne - Chennevières"),
        schemaStop("IDFM:73042", "Champigny"),
        schemaStop("IDFM:70359", "Le Parc de Saint-Maur"),
        schemaStop("IDFM:70393", "Saint-Maur - Créteil"),
        schemaStop("IDFM:70640", "Joinville-le-Pont"),
        schemaStop("IDFM:71590", "Nogent-sur-Marne"),
        schemaStop("IDFM:71630", "Fontenay-sous-Bois"),
    ]

    private static let rerAMarneBranch = [
        schemaStop("IDFM:68385", "Marne-la-Vallée - Chessy"),
        schemaStop("IDFM:68266", "Val d'Europe"),
        schemaStop("IDFM:68105", "Bussy-Saint-Georges"),
        schemaStop("IDFM:68129", "Torcy"),
        schemaStop("IDFM:68123", "Lognes"),
        schemaStop("IDFM:68153", "Noisiel"),
        schemaStop("IDFM:73163", "Noisy - Champs"),
        schemaStop("IDFM:412697", "Noisy-le-Grand - Mont d'Est"),
        schemaStop("IDFM:73166", "Bry-sur-Marne"),
        schemaStop("IDFM:73190", "Neuilly-Plaisance"),
        schemaStop("IDFM:71718", "Val de Fontenay", interchange: true),
    ]

    private static let rerATrunk = [
        schemaStop("IDFM:71651", "Vincennes"),
        schemaStop("IDFM:71673", "Nation", interchange: true),
        schemaStop("IDFM:73626", "Gare de Lyon", interchange: true),
        schemaStop("IDFM:474151", "Châtelet - Les Halles", interchange: true),
        schemaStop("IDFM:478926", "Auber"),
        schemaStop("IDFM:71347", "Charles de Gaulle - Étoile", interchange: true),
        schemaStop("IDFM:71517", "La Défense", interchange: true),
        schemaStop("IDFM:70945", "Nanterre - Préfecture"),
    ]

    private static let rerACergyPoissyStem = [
        schemaStop("IDFM:64741", "Houilles - Carrières-sur-Seine", interchange: true),
        schemaStop("IDFM:64918", "Sartrouville", interchange: true),
        schemaStop("IDFM:65048", "Maisons-Laffitte", interchange: true),
    ]

    private static let rerACergyBranch = [
        schemaStop("IDFM:73604", "Achères Ville", interchange: true),
        schemaStop("IDFM:73605", "Conflans Fin d'Oise", interchange: true),
        schemaStop("IDFM:66436", "Neuville - Université", interchange: true),
        schemaStop("IDFM:66696", "Cergy Préfecture", interchange: true),
        schemaStop("IDFM:66858", "Cergy Saint-Christophe", interchange: true),
        schemaStop("IDFM:66834", "Cergy le Haut", interchange: true),
    ]

    private static let rerAPoissyBranch = [
        schemaStop("IDFM:65190", "Achères Grand Cormier"),
        schemaStop("IDFM:64883", "Poissy", interchange: true),
    ]

    private static let rerASaintGermainBranch = [
        schemaStop("IDFM:70956", "Nanterre Université", interchange: true),
        schemaStop("IDFM:70940", "Nanterre - Ville"),
        schemaStop("IDFM:70902", "Rueil-Malmaison"),
        schemaStop("IDFM:64483", "Chatou - Croissy"),
        schemaStop("IDFM:64514", "Le Vésinet - Centre"),
        schemaStop("IDFM:64582", "Le Vésinet - Le Pecq"),
        schemaStop("IDFM:64589", "Saint-Germain-en-Laye", interchange: true),
    ]

    private static let rerAEastOrigins = ["IDFM:72881", "IDFM:68385"]
    private static let rerAWestTermini = ["IDFM:66834", "IDFM:64883", "IDFM:64589"]

    /// Full real topology: two eastern branches, the Paris trunk, a western
    /// Saint-Germain branch, and the shared stem that later forks to Cergy and
    /// Poissy.
    static let rerADetail = LineDetail(
        route: rerA,
        branches: [],
        directions: [
            LineDirection(
                id: "direction-0",
                directionId: 0,
                label: "Cergy le Haut / Poissy / Saint-Germain-en-Laye",
                sections: [
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Boissy-Saint-Léger",
                        origins: ["IDFM:72881"],
                        termini: rerAWestTermini,
                        stops: rerABoissyBranch
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Marne-la-Vallée - Chessy",
                        origins: ["IDFM:68385"],
                        termini: rerAWestTermini,
                        stops: rerAMarneBranch
                    ),
                    LineSchemaSection(
                        role: .trunk,
                        label: nil,
                        origins: rerAEastOrigins,
                        termini: rerAWestTermini,
                        stops: rerATrunk
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branches Cergy le Haut / Poissy",
                        origins: rerAEastOrigins,
                        termini: ["IDFM:66834", "IDFM:64883"],
                        stops: rerACergyPoissyStem
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Cergy le Haut",
                        origins: rerAEastOrigins,
                        termini: ["IDFM:66834"],
                        stops: rerACergyBranch
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Poissy",
                        origins: rerAEastOrigins,
                        termini: ["IDFM:64883"],
                        stops: rerAPoissyBranch
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Saint-Germain-en-Laye",
                        origins: rerAEastOrigins,
                        termini: ["IDFM:64589"],
                        stops: rerASaintGermainBranch
                    ),
                ]
            ),
            LineDirection(
                id: "direction-1",
                directionId: 1,
                label: "Boissy-Saint-Léger / Marne-la-Vallée - Chessy",
                sections: [
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Saint-Germain-en-Laye",
                        origins: ["IDFM:64589"],
                        termini: rerAEastOrigins,
                        stops: rerASaintGermainBranch.reversed()
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Cergy le Haut",
                        origins: ["IDFM:66834"],
                        termini: rerAEastOrigins,
                        stops: rerACergyBranch.reversed()
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Poissy",
                        origins: ["IDFM:64883"],
                        termini: rerAEastOrigins,
                        stops: rerAPoissyBranch.reversed()
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branches Cergy le Haut / Poissy",
                        origins: ["IDFM:66834", "IDFM:64883"],
                        termini: rerAEastOrigins,
                        stops: rerACergyPoissyStem.reversed()
                    ),
                    LineSchemaSection(
                        role: .trunk,
                        label: nil,
                        origins: rerAWestTermini,
                        termini: rerAEastOrigins,
                        stops: rerATrunk.reversed()
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Boissy-Saint-Léger",
                        origins: rerAWestTermini,
                        termini: ["IDFM:72881"],
                        stops: rerABoissyBranch.reversed()
                    ),
                    LineSchemaSection(
                        role: .branch,
                        label: "Branche Marne-la-Vallée - Chessy",
                        origins: rerAWestTermini,
                        termini: ["IDFM:68385"],
                        stops: rerAMarneBranch.reversed()
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
                        fromStopID: "IDFM:412697",
                        fromName: "Noisy-le-Grand - Mont d'Est",
                        toStopID: "IDFM:68385",
                        toName: "Marne-la-Vallée - Chessy"
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
                        fromStopID: "IDFM:478926",
                        fromName: "Auber",
                        toStopID: "IDFM:73626",
                        toName: "Gare de Lyon"
                    )
                ],
                updatedAt: nil
            ),
        ]
    )
}
