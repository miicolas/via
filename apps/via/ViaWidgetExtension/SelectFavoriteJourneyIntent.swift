import AppIntents

/// Which favourite this widget launches.
///
/// Optional on purpose: a widget placed before any favourite exists still has
/// to draw something, and it then follows the traveller's first favourite until
/// they pick one deliberately.
struct SelectFavoriteJourneyIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Trajet favori"
    static let description = IntentDescription("Choisissez le trajet que ce widget lance.")

    @Parameter(title: "Trajet")
    var favorite: FavoriteJourneyEntity?

    init() {}

    init(favorite: FavoriteJourneyEntity?) {
        self.favorite = favorite
    }
}
