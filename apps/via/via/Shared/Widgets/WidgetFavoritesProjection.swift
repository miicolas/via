import Foundation

/// Turns account state and the Lignes board into the flat values the widget
/// extension draws.
///
/// The whole app→widget contract is this one function pair, so a favourite
/// renamed in Réglages and a favourite drawn on the Lock Screen cannot word
/// themselves differently.
enum WidgetFavoritesProjection {
    /// How many favourites cross the App Group. Far more than any widget shows
    /// at once; the cap is there so a traveller with fifty saved destinations
    /// does not push a fifty-entry blob through a container the extension
    /// re-reads on every reload.
    static let journeyLimit = 12
    static let lineLimit = 12

    /// Maison and Travail lead — the two with a fixed role, and the two used
    /// daily — then the saved destinations in the order the account keeps them.
    static func journeys(
        places: [SavedPlace],
        destinations: [SavedDestination]
    ) -> [WidgetFavoriteJourney] {
        let roles: [SavedPlace.Role] = [.home, .work]
        let saved = roles.compactMap { role in
            places.first { $0.role == role }.map { place in
                WidgetFavoriteJourney(
                    id: WidgetFavoriteToken.token(for: place),
                    label: place.role.displayTitle,
                    destinationName: place.name,
                    systemImage: place.systemImage
                )
            }
        }

        let others = destinations
            .sorted { $0.position < $1.position }
            .map { destination in
                WidgetFavoriteJourney(
                    id: WidgetFavoriteToken.token(for: destination),
                    label: destination.label,
                    destinationName: destination.name,
                    systemImage: destination.systemImage
                )
            }

        return Array((saved + others).prefix(journeyLimit))
    }

    /// Saved lines with their current condition, worst first so a widget that
    /// only has room for four tiles shows the four worth looking at. Ties keep
    /// the order the traveller saved them in.
    static func lines(_ statuses: [LineStatus]) -> [WidgetLineStatus] {
        statuses
            .enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element.condition.displayPriority
                let right = rhs.element.condition.displayPriority
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .prefix(lineLimit)
            .map { _, status in
                WidgetLineStatus(
                    routeID: status.route.id.rawValue,
                    shortName: status.route.shortName,
                    modeName: WidgetTransitModeName.french(forMode: status.route.mode.rawValue),
                    colorHex: status.route.colorHex,
                    textColorHex: status.route.textColorHex,
                    condition: WidgetLineCondition(rawValue: status.condition.rawValue) ?? .normal,
                    summary: status.summary,
                    hasUpcomingClosure: status.upcoming != nil
                )
            }
    }
}

/// The identifier a widget carries for a favourite, and the way back to the
/// place it names.
///
/// A home/work place and a saved destination are one thing to a widget — a
/// journey the traveller starts with one tap — so they share one token space,
/// with `ViaWidgetLink.placeTokenPrefix` telling them apart.
enum WidgetFavoriteToken {
    static func token(for place: SavedPlace) -> String {
        ViaWidgetLink.placeTokenPrefix + place.role.rawValue
    }

    static func token(for destination: SavedDestination) -> String {
        destination.id.uuidString
    }

    /// The destination a widget link names, or `nil` when the favourite behind
    /// it was deleted since the widget was configured.
    static func searchResult(
        for token: String,
        places: [SavedPlace],
        destinations: [SavedDestination]
    ) -> SearchResult? {
        if token.hasPrefix(ViaWidgetLink.placeTokenPrefix) {
            let rawRole = String(token.dropFirst(ViaWidgetLink.placeTokenPrefix.count))
            guard let role = SavedPlace.Role(rawValue: rawRole) else { return nil }
            return places.first { $0.role == role }?.searchResult
        }

        guard let id = UUID(uuidString: token) else { return nil }
        return destinations.first { $0.id == id }?.searchResult
    }
}
