import AppIntents

/// What the saved-lines widget shows.
///
/// One switch, because there are two ways to read this widget: as the state of
/// everything the traveller follows, or as an alarm that stays quiet while the
/// network behaves.
struct FavoriteLinesConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Lignes favorites"
    static let description = IntentDescription("Choisissez ce que ce widget affiche.")

    @Parameter(title: "Uniquement les lignes perturbées", default: false)
    var disruptedOnly: Bool

    init() {}

    init(disruptedOnly: Bool) {
        self.disruptedOnly = disruptedOnly
    }
}
