import Foundation

/// A JSON file under `Application Support/Via`, kept out of iCloud backups.
///
/// Push and reminder state belongs to one installation: restoring it onto
/// another device would resurrect notifications for a token that no longer
/// exists. The exclusion flag is the rule that prevents it, so it lives here
/// rather than in each store that happens to remember to set it.
struct LocalJSONFile: Sendable {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(name: String) {
        self.init(
            url: FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "Via", directoryHint: .isDirectory)
                .appending(path: name)
        )
    }

    /// `nil` when the file has never been written; every other failure throws.
    func read() throws -> Data? {
        do {
            return try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
    }

    func write(_ data: Data) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try excludeFromBackup(directory)
        try data.write(to: url, options: .atomic)
        try excludeFromBackup(url)
    }

    func remove() throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }

    private func excludeFromBackup(_ target: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = target
        try mutable.setResourceValues(values)
    }
}
