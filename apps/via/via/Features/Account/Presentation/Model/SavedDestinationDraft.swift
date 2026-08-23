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

enum SavedDestinationSelectionContext: Sendable {
    case place(SavedPlace.Role)
    case destination
    case replacement(SavedDestinationDraft)
}
