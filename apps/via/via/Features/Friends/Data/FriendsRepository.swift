import Foundation

protocol FriendsRepository: Sendable {
    func list() async throws -> [ViaFriend]
    func createInvitation() async throws -> FriendInvitationLink
    func previewInvitation(token: String) async throws -> FriendInvitationPreview
    func acceptInvitation(token: String) async throws -> ViaFriend
    func remove(userId: String) async throws
}

struct LiveFriendsRepository: FriendsRepository {
    let transport: APITransport

    func list() async throws -> [ViaFriend] {
        try await transport.perform("friends.list") { client in
            switch try await client.friends_period_list(.init()) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: FriendsListDTO.self).domain
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func createInvitation() async throws -> FriendInvitationLink {
        try await transport.perform("friends.createInvitation") { client in
            let payload = Operations.friends_period_createInvitation.Input.Body.jsonPayload(
                idempotencyKey: UUID().uuidString.lowercased()
            )
            switch try await client.friends_period_createInvitation(.init(body: .json(payload))) {
            case .ok(let response):
                let dto = try transport.convert(
                    response.body.json,
                    to: FriendInvitationCreateDTO.self
                )
                guard let url = URL(string: dto.url) else { throw ViaError.decoding }
                return FriendInvitationLink(id: dto.invitation.id, url: url, expiresAt: dto.invitation.expiresAt)
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func previewInvitation(token: String) async throws -> FriendInvitationPreview {
        try await transport.perform("friends.previewInvitation") { client in
            switch try await client.friends_period_previewInvitation(
                .init(query: .init(token: token))
            ) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: FriendInvitationPreview.self)
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func acceptInvitation(token: String) async throws -> ViaFriend {
        try await transport.perform("friends.acceptInvitation") { client in
            let payload = Operations.friends_period_acceptInvitation.Input.Body.jsonPayload(
                token: token
            )
            switch try await client.friends_period_acceptInvitation(.init(body: .json(payload))) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: FriendAcceptDTO.self).friendship
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func remove(userId: String) async throws {
        try await transport.perform("friends.remove") { client in
            let payload = Operations.friends_period_remove.Input.Body.jsonPayload(userId: userId)
            switch try await client.friends_period_remove(.init(body: .json(payload))) {
            case .ok: return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }
}

struct InMemoryFriendsRepository: FriendsRepository {
    var friends: [ViaFriend] = []
    func list() async throws -> [ViaFriend] { friends }
    func createInvitation() async throws -> FriendInvitationLink { throw ViaError.unavailable }
    func previewInvitation(token: String) async throws -> FriendInvitationPreview { throw ViaError.unavailable }
    func acceptInvitation(token: String) async throws -> ViaFriend { throw ViaError.unavailable }
    func remove(userId: String) async throws {}
}

private struct FriendsListDTO: Decodable {
    let friends: [FriendshipDTO]

    var domain: [ViaFriend] { friends.map(\.domain) }

    struct FriendshipDTO: Decodable {
        let userId: String
        let displayName: String
        let initials: String
        let friendsSince: Date

        var domain: ViaFriend {
            ViaFriend(id: userId, displayName: displayName, initials: initials, createdAt: friendsSince)
        }
    }

    private enum CodingKeys: String, CodingKey { case friends }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        friends = try container.decode([FriendshipDTO].self, forKey: .friends)
    }
}

private struct FriendInvitationCreateDTO: Decodable {
    struct Invitation: Decodable { let id: String; let expiresAt: Date }
    let invitation: Invitation
    let url: String
}

private struct FriendAcceptDTO: Decodable {
    struct FriendshipDTO: Decodable {
        let userId: String
        let displayName: String
        let initials: String
        let friendsSince: Date

        var domain: ViaFriend {
            ViaFriend(id: userId, displayName: displayName, initials: initials, createdAt: friendsSince)
        }
    }
    let rawFriendship: FriendshipDTO

    var friendship: ViaFriend { rawFriendship.domain }

    private enum CodingKeys: String, CodingKey { case rawFriendship = "friendship" }
}
