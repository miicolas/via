import Foundation

protocol AccountRemote: Sendable {
    func synchronize(_ operations: [AccountSyncOperation]) async throws -> AccountSyncResult
    func delete(using proof: AccountDeletionProof) async throws
}

struct LiveAccountRemote: AccountRemote {
    let transport: APITransport

    func synchronize(_ operations: [AccountSyncOperation]) async throws -> AccountSyncResult {
        try await transport.perform("account_sync") { client in
            typealias Payload = Operations.account_period_sync.Input.Body.jsonPayload
            let payload = try transport.convert(
                AccountSyncRequest(operations: operations),
                to: Payload.self
            )
            switch try await client.account_period_sync(.init(body: .json(payload))) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: AccountSyncResult.self)
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func delete(using proof: AccountDeletionProof) async throws {
        try await transport.perform("account_delete") { client in
            let payload = Operations.account_period_delete.Input.Body.jsonPayload(
                identityToken: proof.identityToken,
                authorizationCode: proof.authorizationCode,
                nonce: proof.nonce
            )
            switch try await client.account_period_delete(.init(body: .json(payload))) {
            case .ok:
                return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }
}

actor InMemoryAccountRemote: AccountRemote {
    private var syncResult: AccountSyncResult?
    private var error: ViaError?

    init(syncResult: AccountSyncResult? = nil, error: ViaError? = nil) {
        self.syncResult = syncResult
        self.error = error
    }

    func synchronize(_ operations: [AccountSyncOperation]) throws -> AccountSyncResult {
        if let error { throw error }
        return syncResult ?? AccountSyncResult(
            appliedOperationIDs: operations.map(\.operationID),
            favorites: [],
            recents: [],
            places: [],
            preferences: .empty,
            syncedAt: .now
        )
    }

    func delete(using proof: AccountDeletionProof) throws {
        if let error { throw error }
    }
}

private struct AccountSyncRequest: Encodable {
    let operations: [AccountSyncOperation]
}
