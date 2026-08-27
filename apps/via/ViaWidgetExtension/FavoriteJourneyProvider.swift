import WidgetKit

struct FavoriteJourneyEntry: TimelineEntry {
    let date: Date
    /// The favourite this widget launches. `nil` when nothing is saved yet, or
    /// when the one it was configured with has since been deleted.
    let journey: WidgetFavoriteJourney?
    /// The traveller's other favourites, for the sizes with room to offer them.
    let others: [WidgetFavoriteJourney]

    init(date: Date, journey: WidgetFavoriteJourney?, others: [WidgetFavoriteJourney] = []) {
        self.date = date
        self.journey = journey
        self.others = others
    }
}

struct FavoriteJourneyProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FavoriteJourneyEntry {
        FavoriteJourneyEntry(
            date: .now,
            journey: Self.placeholderJourney,
            others: Self.placeholderOthers
        )
    }

    func snapshot(
        for configuration: SelectFavoriteJourneyIntent,
        in context: Context
    ) async -> FavoriteJourneyEntry {
        entry(for: configuration, in: context)
    }

    /// `.never`: a favourite only changes when the traveller edits it, and the
    /// app reloads the timelines itself when it does. Asking the system for a
    /// refresh on a schedule would spend the widget budget re-reading a file
    /// that cannot have moved.
    func timeline(
        for configuration: SelectFavoriteJourneyIntent,
        in context: Context
    ) async -> Timeline<FavoriteJourneyEntry> {
        Timeline(entries: [entry(for: configuration, in: context)], policy: .never)
    }

    private func entry(
        for configuration: SelectFavoriteJourneyIntent,
        in context: Context
    ) -> FavoriteJourneyEntry {
        let saved = WidgetFavoritesStore().read().journeys
        // Re-resolved by identifier rather than drawn from the configuration:
        // the entity was captured when the widget was placed, and a favourite
        // renamed since must not keep its old wording on the Home Screen.
        let chosen = configuration.favorite
            .flatMap { entity in saved.first { $0.id == entity.id } }
            ?? saved.first

        return FavoriteJourneyEntry(
            date: .now,
            journey: chosen,
            others: saved.filter { $0.id != chosen?.id }
        )
    }

    private static let placeholderJourney = WidgetFavoriteJourney(
        id: "place:work",
        label: "Travail",
        destinationName: "Gare de Lyon",
        systemImage: "briefcase.fill"
    )

    private static let placeholderOthers = [
        WidgetFavoriteJourney(
            id: "place:home",
            label: "Maison",
            destinationName: "Nation",
            systemImage: "house.fill"
        ),
        WidgetFavoriteJourney(
            id: "00000000-0000-0000-0000-000000000001",
            label: "Sport",
            destinationName: "Bercy",
            systemImage: "dumbbell.fill"
        ),
        WidgetFavoriteJourney(
            id: "00000000-0000-0000-0000-000000000002",
            label: "Roissy",
            destinationName: "Aéroport CDG 2",
            systemImage: "airplane"
        ),
    ]
}
