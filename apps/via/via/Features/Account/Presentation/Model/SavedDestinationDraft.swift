import Foundation

struct SavedDestinationDraft: Identifiable, Sendable {
    enum Target: Sendable {
        case place(SavedPlace.Role, existing: SavedPlace?)
        case destination(existing: SavedDestination?)
    }

    let id: UUID
    let target: Target
    var result: SearchResult
    var label: String
    var systemImage: String

    init(
        id: UUID = UUID(),
        target: Target,
        result: SearchResult,
        label: String,
        systemImage: String
    ) {
        self.id = id
        self.target = target
        self.result = result
        self.label = label
        self.systemImage = systemImage
    }

    var role: SavedPlace.Role? {
        guard case .place(let role, _) = target else { return nil }
        return role
    }

    var existingDestination: SavedDestination? {
        guard case .destination(let existing) = target else { return nil }
        return existing
    }

    var isNew: Bool {
        switch target {
        case .place(_, let existing): existing == nil
        case .destination(let existing): existing == nil
        }
    }

    func replacingResult(_ result: SearchResult) -> Self {
        var copy = self
        copy.result = result
        return copy
    }
}

enum SavedDestinationSelectionContext: Sendable, Identifiable {
    case place(SavedPlace.Role)
    case destination
    case replacement(SavedDestinationDraft)

    var id: String {
        switch self {
        case .place(let role): "place-\(role.rawValue)"
        case .destination: "destination"
        case .replacement(let draft): "replacement-\(draft.id.uuidString)"
        }
    }

    /// What the address search is being opened for, as a sheet title.
    var searchTitle: String {
        switch self {
        case .place(let role): role.displayTitle
        case .destination: "Nouveau favori"
        case .replacement(let draft): draft.role?.displayTitle ?? draft.label
        }
    }
}

/// What the Favorites settings should open on when it is presented from a
/// shortcut the user tapped elsewhere.
enum FavoritesFocus: Sendable, Equatable {
    case place(SavedPlace.Role)
    case addDestination
}
