import Foundation

enum ProfileScope: Hashable, Sendable {
    case anonymous
    case user(String)

    var storageIdentifier: String {
        switch self {
        case .anonymous:
            return "anonymous"
        case .user(let userID):
            let encoded = Data(userID.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "=", with: "")
            return "user-\(encoded)"
        }
    }
}

struct ProfileSnapshot: Sendable, Equatable {
    var displayName: String
    var avatarData: Data?
    var updatedAt: Date

    static let empty = ProfileSnapshot(displayName: "", avatarData: nil, updatedAt: .distantPast)

    var normalizedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var initials: String? {
        let value = normalizedDisplayName
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
        return value.isEmpty ? nil : value
    }
}

struct ProfileContact: Sendable, Equatable {
    var displayName: String?
    var avatarData: Data?
}

enum TransitModePreference: String, CaseIterable, Sendable, Identifiable {
    case normal
    case preferred
    case excluded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .preferred: "Préférer"
        case .excluded: "Éviter"
        }
    }
}
