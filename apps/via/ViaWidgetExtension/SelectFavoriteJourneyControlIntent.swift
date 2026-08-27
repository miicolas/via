import AppIntents

/// Which favourite a control button launches.
///
/// A second declaration of the same choice, because a control is configured
/// through `ControlConfigurationIntent` and a widget through
/// `WidgetConfigurationIntent`: the two are different surfaces to the system,
/// even where they ask the traveller the same question. Both resolve through
/// `FavoriteJourneyQuery`, so there is still one list of favourites.
struct SelectFavoriteJourneyControlIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Trajet favori"
    static let description = IntentDescription("Choisissez le trajet que ce bouton lance.")

    @Parameter(title: "Trajet")
    var favorite: FavoriteJourneyEntity?

    init() {}

    init(favorite: FavoriteJourneyEntity?) {
        self.favorite = favorite
    }
}
