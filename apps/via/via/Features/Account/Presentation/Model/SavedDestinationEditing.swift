import Foundation

/// Turns a chosen search result into the draft the editor works on, and
/// writes that draft back to the account. Two screens drive the same flow —
/// the shortcut rail in the Stations tab and the Favorites settings — so the
/// decisions live here rather than in whichever view happens to host them.
@MainActor
enum SavedDestinationEditing {
    /// The draft to edit for this result. A place already saved elsewhere
    /// wins over the requested context: picking an address that is already
    /// "Maison" reopens Maison instead of silently saving it twice.
    static func draft(
        for result: SearchResult,
        context: SavedDestinationSelectionContext,
        in accountModel: AccountModel
    ) -> SavedDestinationDraft {
        if case .replacement(let draft) = context {
            let editedDestinationID = draft.existingDestination?.destinationID
            let editedPlaceID: String? = switch draft.target {
            case .place(_, let existing): existing?.id
            case .destination: nil
            }

            if let place = accountModel.savedPlace(for: result), place.id != editedPlaceID {
                return self.draft(editing: place)
            }
            if let destination = accountModel.savedDestination(for: result),
               destination.destinationID != editedDestinationID {
                return self.draft(editing: destination)
            }
            return draft.replacingResult(result)
        }

        if let place = accountModel.savedPlace(for: result) {
            return self.draft(editing: place)
        }
        if let destination = accountModel.savedDestination(for: result) {
            return self.draft(editing: destination)
        }

        switch context {
        case .place(let role):
            return SavedDestinationDraft(
                target: .place(role, existing: nil),
                result: result,
                label: role.displayTitle,
                systemImage: role.systemImage
            )
        case .destination:
            return SavedDestinationDraft(
                target: .destination(existing: nil),
                result: result,
                label: result.name,
                systemImage: SavedDestinationSymbols.suggestion(for: result)
            )
        case .replacement(let draft):
            return draft.replacingResult(result)
        }
    }

    static func draft(editing place: SavedPlace) -> SavedDestinationDraft {
        SavedDestinationDraft(
            target: .place(place.role, existing: place),
            result: place.searchResult,
            label: place.role.displayTitle,
            systemImage: SavedDestinationSymbols.resolved(
                place.systemImage,
                fallback: place.role.systemImage
            )
        )
    }

    static func draft(editing destination: SavedDestination) -> SavedDestinationDraft {
        SavedDestinationDraft(
            target: .destination(existing: destination),
            result: destination.searchResult,
            label: destination.label,
            systemImage: SavedDestinationSymbols.resolved(destination.systemImage)
        )
    }

    /// The draft for a result that is not tied to a pinned role yet: reopens
    /// whatever the address is already saved as, otherwise starts a new
    /// free-form destination. This is the star in the search results.
    static func draft(
        for result: SearchResult,
        in accountModel: AccountModel
    ) -> SavedDestinationDraft {
        draft(for: result, context: .destination, in: accountModel)
    }

    static func save(
        _ draft: SavedDestinationDraft,
        label: String,
        systemImage: String,
        in accountModel: AccountModel
    ) {
        switch draft.target {
        case .place(let role, _):
            accountModel.setPlace(draft.result, role: role, systemImage: systemImage)
        case .destination(let existing):
            accountModel.saveDestination(
                draft.result,
                label: label,
                systemImage: systemImage,
                editing: existing
            )
        }
    }

    static func deleteAction(
        for draft: SavedDestinationDraft,
        in accountModel: AccountModel
    ) -> (() -> Void)? {
        switch draft.target {
        case .place(let role, let existing):
            guard existing != nil else { return nil }
            return { accountModel.removePlace(for: role) }
        case .destination(let existing):
            guard let existing else { return nil }
            return { accountModel.removeDestination(id: existing.id) }
        }
    }
}
