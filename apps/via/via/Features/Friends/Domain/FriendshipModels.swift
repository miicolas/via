import Foundation

struct ViaFriend: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let displayName: String
    let initials: String
    let createdAt: Date
}

struct FriendInvitationPreview: Codable, Sendable, Hashable {
    enum Status: String, Codable, Sendable { case available, expired, revoked }

    let inviterDisplayName: String
    let status: Status
    let expiresAt: Date

    var inviterInitials: String {
        inviterDisplayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

struct FriendInvitationLink: Sendable, Hashable, Identifiable {
    let id: String
    let url: URL
    let expiresAt: Date
}
