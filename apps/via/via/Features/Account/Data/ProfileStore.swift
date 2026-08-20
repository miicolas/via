import Foundation

protocol ProfileStoring: Sendable {
    func load(scope: ProfileScope) throws -> ProfileSnapshot?
    func save(_ snapshot: ProfileSnapshot, scope: ProfileScope) throws
    func erase(scope: ProfileScope) throws
    func eraseAll() throws
}

final class LocalProfileStore: ProfileStoring, @unchecked Sendable {
    private struct Metadata: Codable {
        var displayName: String
        var updatedAt: Date
    }

    private let defaults: UserDefaults
    private let directoryURL: URL
    private let metadataPrefix = "via.profile.metadata.v1."
    private let knownScopesKey = "via.profile.scopes.v1"

    init(
        defaults: UserDefaults = .standard,
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.directoryURL = directoryURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "ViaProfiles", directoryHint: .isDirectory)
    }

    func load(scope: ProfileScope) throws -> ProfileSnapshot? {
        let key = metadataKey(for: scope)
        guard let data = defaults.data(forKey: key) else { return nil }
        let metadata = try JSONDecoder.via.decode(Metadata.self, from: data)
        let avatarData = try? Data(contentsOf: avatarURL(for: scope))
        return ProfileSnapshot(
            displayName: metadata.displayName,
            avatarData: avatarData,
            updatedAt: metadata.updatedAt
        )
    }

    func save(_ snapshot: ProfileSnapshot, scope: ProfileScope) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let avatarURL = avatarURL(for: scope)
        if let avatarData = snapshot.avatarData {
            try avatarData.write(to: avatarURL, options: .atomic)
        } else if fileManager.fileExists(atPath: avatarURL.path) {
            try fileManager.removeItem(at: avatarURL)
        }

        let metadata = Metadata(displayName: snapshot.normalizedDisplayName, updatedAt: snapshot.updatedAt)
        defaults.set(try JSONEncoder.via.encode(metadata), forKey: metadataKey(for: scope))
        register(scope)
    }

    func erase(scope: ProfileScope) throws {
        defaults.removeObject(forKey: metadataKey(for: scope))
        let url = avatarURL(for: scope)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        var scopes = knownScopes
        scopes.removeAll { $0 == scope.storageIdentifier }
        defaults.set(scopes, forKey: knownScopesKey)
    }

    func eraseAll() throws {
        for identifier in knownScopes {
            defaults.removeObject(forKey: metadataPrefix + identifier)
        }
        defaults.removeObject(forKey: knownScopesKey)
        if FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.removeItem(at: directoryURL)
        }
    }

    private var knownScopes: [String] {
        defaults.stringArray(forKey: knownScopesKey) ?? []
    }

    private func register(_ scope: ProfileScope) {
        var scopes = knownScopes
        guard !scopes.contains(scope.storageIdentifier) else { return }
        scopes.append(scope.storageIdentifier)
        defaults.set(scopes, forKey: knownScopesKey)
    }

    private func metadataKey(for scope: ProfileScope) -> String {
        metadataPrefix + scope.storageIdentifier
    }

    private func avatarURL(for scope: ProfileScope) -> URL {
        directoryURL.appending(path: scope.storageIdentifier + ".jpg", directoryHint: .notDirectory)
    }
}

final class InMemoryProfileStore: ProfileStoring, @unchecked Sendable {
    private var snapshots: [ProfileScope: ProfileSnapshot]

    init(snapshots: [ProfileScope: ProfileSnapshot] = [:]) {
        self.snapshots = snapshots
    }

    func load(scope: ProfileScope) throws -> ProfileSnapshot? { snapshots[scope] }
    func save(_ snapshot: ProfileSnapshot, scope: ProfileScope) throws { snapshots[scope] = snapshot }
    func erase(scope: ProfileScope) throws { snapshots[scope] = nil }
    func eraseAll() throws { snapshots.removeAll() }
}
