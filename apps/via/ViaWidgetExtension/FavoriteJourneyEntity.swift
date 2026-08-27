import AppIntents

/// A favourite as the widget configuration screen offers it.
///
/// The entity carries a copy of what the tile draws so the picker can show
/// "Travail — Gare de Lyon" rather than an identifier, but the widget itself
/// re-reads the favourite from the snapshot at render time: a favourite renamed
/// after the widget was placed must not keep its old wording on the screen.
struct FavoriteJourneyEntity: AppEntity {
    let id: String
    let label: String
    let destinationName: String
    let systemImage: String

    init(_ journey: WidgetFavoriteJourney) {
        id = journey.id
        label = journey.label
        destinationName = journey.destinationName
        systemImage = journey.systemImage
    }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Trajet favori"
    static let defaultQuery = FavoriteJourneyQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(label)",
            subtitle: "\(destinationName)",
            image: .init(systemName: systemImage)
        )
    }
}

/// The favourites the traveller saved, read straight from the App Group.
///
/// No network and no account: the picker has to answer while the configuration
/// sheet is open, and the snapshot is already the app's answer to "what did
/// this traveller save".
struct FavoriteJourneyQuery: EntityQuery {
    func entities(for identifiers: [FavoriteJourneyEntity.ID]) async throws -> [FavoriteJourneyEntity] {
        let saved = Self.saved()
        return identifiers.compactMap { identifier in
            saved.first { $0.id == identifier }
        }
    }

    func suggestedEntities() async throws -> [FavoriteJourneyEntity] {
        Self.saved()
    }

    static func saved() -> [FavoriteJourneyEntity] {
        WidgetFavoritesStore().read().journeys.map(FavoriteJourneyEntity.init)
    }
}
