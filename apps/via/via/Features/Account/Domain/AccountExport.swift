import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Portable account data. Authentication credentials, session tokens, Apple
/// proofs and queued internal operations intentionally never enter this type.
struct AccountExport: Codable, Hashable, Sendable, Transferable {
    let schemaVersion: Int
    let exportedAt: Date
    let favorites: [FavoriteStation]
    let places: [SavedPlace]
    let recentSearches: [RecentSearch]
    let preferences: TransportPreferences

    init(snapshot: AccountSnapshot, exportedAt: Date) {
        schemaVersion = 1
        self.exportedAt = exportedAt
        favorites = snapshot.favorites
        places = snapshot.places
        recentSearches = snapshot.recentSearches
        preferences = snapshot.transportPreferences
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { export in
            try JSONEncoder.via.encode(export)
        }
    }
}
