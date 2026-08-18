import Foundation

/// Fixture-first source for the Lines tab. A live adapter can later implement
/// `LineStatusRepository` without changing the shell or card components.
struct PreviewLineStatusRepository: LineStatusRepository {
    let statuses: [LineStatus]

    init(statuses: [LineStatus] = Self.defaultStatuses) {
        self.statuses = statuses
    }

    func loadStatuses() async throws -> [LineStatus] {
        statuses
    }

    static let defaultStatuses: [LineStatus] = [
        LineStatus(
            id: "metro-4",
            name: "4",
            mode: .metro,
            color: ColorToken(name: "Violet", hex: "#B42C91"),
            condition: .disrupted,
            summary: "Trafic perturbé entre Châtelet et Gare du Nord.",
            affectedStops: ["Châtelet", "Gare de l’Est", "Gare du Nord"],
            updatedAt: Date(timeIntervalSince1970: 1_755_400_000),
            direction: "Porte de Clignancourt"
        ),
        LineStatus(
            id: "rer-b",
            name: "B",
            mode: .rer,
            color: ColorToken(name: "Bleu", hex: "#5291CE"),
            condition: .attention,
            summary: "Des ralentissements sont à prévoir ce matin.",
            affectedStops: ["Châtelet–Les Halles", "Saint-Michel–Notre-Dame"],
            updatedAt: Date(timeIntervalSince1970: 1_755_398_800),
            direction: "Aéroport CDG"
        ),
        LineStatus(
            id: "tram-t3a",
            name: "T3a",
            mode: .tram,
            color: ColorToken(name: "Orange", hex: "#FF7F00"),
            condition: .normal,
            summary: "Service normal. Prochains départs à l’heure.",
            affectedStops: [],
            updatedAt: Date(timeIntervalSince1970: 1_755_397_500),
            direction: "Porte de Vincennes"
        ),
        LineStatus(
            id: "bus-67",
            name: "67",
            mode: .bus,
            color: ColorToken(name: "Vert", hex: "#6ECA97", textHex: "#111111"),
            condition: .suspended,
            summary: "Ligne suspendue jusqu’à nouvel ordre.",
            affectedStops: ["Hôtel de Ville", "Châtelet", "Porte de Clignancourt"],
            updatedAt: Date(timeIntervalSince1970: 1_755_396_000),
            direction: "Porte de Clignancourt"
        ),
        LineStatus(
            id: "transilien-l",
            name: "L",
            mode: .transilien,
            color: ColorToken(name: "Gris", hex: "#7584BC"),
            condition: .unavailable,
            summary: "Les informations de service sont indisponibles.",
            affectedStops: [],
            updatedAt: nil,
            direction: "Versailles Rive Droite"
        )
    ]
}
