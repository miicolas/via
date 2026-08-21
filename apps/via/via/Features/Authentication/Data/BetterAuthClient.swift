import Foundation

protocol AuthenticationClient: Sendable {
    func signIn(
        with credentials: AppleSignInCredentials,
        existingBearerToken: String?
    ) async throws -> StoredAuthSession
    func signInAnonymously() async throws -> StoredAuthSession
    func validate(_ session: StoredAuthSession) async throws -> StoredAuthSession
    func signOut(bearerToken: String) async throws
    func deleteAnonymousUser(bearerToken: String) async throws
}

final class BetterAuthClient: AuthenticationClient, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession? = nil) {
        self.baseURL = baseURL
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.apiSessionConfiguration(base: .ephemeral)
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 45
            configuration.waitsForConnectivity = true
            self.session = URLSession(configuration: configuration)
        }
    }

    func signIn(
        with credentials: AppleSignInCredentials,
        existingBearerToken: String? = nil
    ) async throws -> StoredAuthSession {
        let name = SignInBody.IDToken.User.Name(
            firstName: credentials.givenName,
            lastName: credentials.familyName
        )
        let appleUser = SignInBody.IDToken.User(
            name: name.isEmpty ? nil : name,
            email: credentials.email
        )
        let body = SignInBody(
            provider: "apple",
            idToken: .init(
                token: credentials.identityToken,
                nonce: credentials.nonce,
                user: appleUser.isEmpty ? nil : appleUser
            )
        )
        var request = try request(
            path: "auth/sign-in/social",
            method: "POST",
            bearerToken: existingBearerToken
        )
        request.httpBody = try JSONEncoder.via.encode(body)

        let (data, response) = try await perform(request)
        let bearer = try signedBearer(from: response)
        let signedIn = try JSONDecoder.via.decode(SignInResponse.self, from: data)
        guard !signedIn.user.id.isEmpty, signedIn.user.isAnonymous != true else {
            throw AuthenticationClientError.invalidResponse
        }

        let provisional = StoredAuthSession(
            bearerToken: bearer,
            user: AuthUser(
                id: signedIn.user.id,
                appleUserIdentifier: credentials.appleUserIdentifier,
                name: signedIn.user.name,
                email: signedIn.user.email,
                isAnonymous: signedIn.user.isAnonymous ?? false
            ),
            expiresAt: .now.addingTimeInterval(30 * 24 * 60 * 60),
            lastValidatedAt: .now
        )
        // The sign-in response already contains a server-issued session. A
        // transient failure during the follow-up validation must not throw the
        // user back to the Apple sheet after a successful authorization.
        do {
            return try await validate(provisional)
        } catch let error as AuthenticationClientError {
            switch error {
            case .transport, .server:
                return provisional
            case .unauthorized, .invalidResponse:
                throw error
            }
        }
    }

    func signInAnonymously() async throws -> StoredAuthSession {
        let request = try request(path: "auth/sign-in/anonymous", method: "POST")
        let (data, response) = try await perform(request)
        let anonymous = try JSONDecoder.via.decode(AnonymousSignInResponse.self, from: data)
        let bearer = try signedBearer(from: response, fallback: anonymous.token)
        let provisional = StoredAuthSession(
            bearerToken: bearer,
            user: AuthUser(
                id: anonymous.user.id,
                appleUserIdentifier: "",
                name: anonymous.user.name,
                email: anonymous.user.email,
                isAnonymous: true
            ),
            expiresAt: .now.addingTimeInterval(30 * 24 * 60 * 60),
            lastValidatedAt: .now
        )
        do {
            return try await validate(provisional)
        } catch let error as AuthenticationClientError {
            switch error {
            case .transport, .server:
                return provisional
            case .unauthorized, .invalidResponse:
                throw error
            }
        }
    }

    func validate(_ storedSession: StoredAuthSession) async throws -> StoredAuthSession {
        let request = try request(
            path: "auth/get-session",
            method: "GET",
            bearerToken: storedSession.bearerToken
        )
        let (data, response) = try await perform(request, retryCount: 1)
        guard let envelope = try JSONDecoder.via.decode(SessionEnvelope?.self, from: data) else {
            throw AuthenticationClientError.unauthorized
        }
        let bearer = response.value(forHTTPHeaderField: "set-auth-token")
            .flatMap { $0.isEmpty ? nil : $0 } ?? storedSession.bearerToken
        return StoredAuthSession(
            bearerToken: bearer,
            user: AuthUser(
                id: envelope.user.id,
                appleUserIdentifier: storedSession.user.appleUserIdentifier,
                name: envelope.user.name,
                email: envelope.user.email,
                isAnonymous: envelope.user.isAnonymous ?? storedSession.user.isAnonymous
            ),
            expiresAt: envelope.session.expiresAt,
            lastValidatedAt: .now
        )
    }

    func signOut(bearerToken: String) async throws {
        let request = try request(
            path: "auth/sign-out",
            method: "POST",
            bearerToken: bearerToken
        )
        _ = try await perform(request)
    }

    func deleteAnonymousUser(bearerToken: String) async throws {
        let request = try request(
            path: "auth/delete-anonymous-user",
            method: "POST",
            bearerToken: bearerToken
        )
        _ = try await perform(request)
    }

    private func request(
        path: String,
        method: String,
        bearerToken: String? = nil
    ) throws -> URLRequest {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform(
        _ request: URLRequest,
        retryCount: Int = 0
    ) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0

        while true {
            do {
                let (data, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse else {
                    throw AuthenticationClientError.invalidResponse
                }
                switch response.statusCode {
                case 200..<300:
                    return (data, response)
                case 401:
                    throw AuthenticationClientError.unauthorized
                case 500...599:
                    throw AuthenticationClientError.server(statusCode: response.statusCode)
                default:
                    throw AuthenticationClientError.invalidResponse
                }
            } catch let error as AuthenticationClientError {
                guard attempt < retryCount, error.isTransient else { throw error }
                attempt += 1
                try await Task.sleep(for: .milliseconds(350))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard attempt < retryCount else {
                    throw AuthenticationClientError.transport
                }
                attempt += 1
                try await Task.sleep(for: .milliseconds(350))
            }
        }
    }

    private func signedBearer(from response: HTTPURLResponse, fallback: String? = nil) throws -> String {
        let bearer = response.value(forHTTPHeaderField: "set-auth-token") ?? fallback
        guard let bearer, bearer.contains(".") else {
            throw AuthenticationClientError.invalidResponse
        }
        return bearer
    }
}

private extension AuthenticationClientError {
    var isTransient: Bool {
        switch self {
        case .transport, .server:
            true
        case .unauthorized, .invalidResponse:
            false
        }
    }
}

private struct SignInBody: Encodable {
    struct IDToken: Encodable {
        struct User: Encodable {
            struct Name: Encodable {
                let firstName: String?
                let lastName: String?

                var isEmpty: Bool { firstName == nil && lastName == nil }
            }

            let name: Name?
            let email: String?

            var isEmpty: Bool { name == nil && email == nil }
        }

        let token: String
        let nonce: String
        let user: User?
    }

    let provider: String
    let idToken: IDToken
}

private struct AuthResponseUser: Decodable {
    let id: String
    let name: String
    let email: String
    let isAnonymous: Bool?
}

private struct SignInResponse: Decodable {
    let user: AuthResponseUser
}

private struct AnonymousSignInResponse: Decodable {
    let token: String?
    let user: AuthResponseUser
}

private struct SessionEnvelope: Decodable {
    struct Session: Decodable {
        let expiresAt: Date
    }

    let session: Session
    let user: AuthResponseUser
}
