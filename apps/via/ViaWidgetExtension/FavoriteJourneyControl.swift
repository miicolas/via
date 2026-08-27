import AppIntents
import SwiftUI
import WidgetKit

/// A shortcut button for one saved journey, placeable on the Lock Screen and
/// in Control Centre.
///
/// The button cannot open a URL by itself — a control runs an App Intent — so
/// it runs `OpenViaRouteIntent`, which leaves the route in the App Group and
/// asks the system to bring Metyro forward.
struct FavoriteJourneyControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: ViaWidgetKind.favoriteJourneyControl,
            provider: Provider()
        ) { value in
            ControlWidgetButton(action: OpenViaRouteIntent(route: value.url)) {
                Label(value.label, systemImage: value.systemImage)
            }
        }
        .displayName("Trajet favori")
        .description("Lance un trajet enregistré dans Metyro.")
    }
}

extension FavoriteJourneyControl {
    /// What the button draws and where it goes. Resolved at render time from
    /// the snapshot rather than from the stored configuration, so a favourite
    /// renamed in the app renames its button too.
    struct Value: Sendable {
        let label: String
        let systemImage: String
        let url: URL

        init(label: String, systemImage: String, url: URL) {
            self.label = label
            self.systemImage = systemImage
            self.url = url
        }

        init(journey: WidgetFavoriteJourney) {
            self.init(
                label: journey.label,
                systemImage: journey.systemImage,
                url: ViaWidgetLink.favoriteJourney(id: journey.id)
            )
        }

        /// Nothing saved yet: the button still has a job — it opens Recherche,
        /// where a favourite is created.
        static let empty = Value(
            label: "Trajet",
            systemImage: "star",
            url: ViaWidgetLink.search
        )
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: SelectFavoriteJourneyControlIntent) -> Value {
            Value(
                journey: WidgetFavoriteJourney(
                    id: "place:work",
                    label: "Travail",
                    destinationName: "Gare de Lyon",
                    systemImage: "briefcase.fill"
                )
            )
        }

        func currentValue(
            configuration: SelectFavoriteJourneyControlIntent
        ) async throws -> Value {
            let saved = WidgetFavoritesStore().read().journeys
            let chosen = configuration.favorite
                .flatMap { entity in saved.first { $0.id == entity.id } }
                ?? saved.first

            guard let chosen else { return .empty }
            return Value(journey: chosen)
        }
    }
}
