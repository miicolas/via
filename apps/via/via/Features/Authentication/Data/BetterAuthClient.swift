import Foundation

protocol AuthenticationClient: Sendable {
    func signIn(with credentials: AppleSignInCredentials) async throws -> StoredAuthSession
    func validate(_ session: StoredAuthSession) async throws -> StoredAuthSession
    func signOut(bearerToken: String) async throws
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
            configuration.timeoutIntervalForRequest = 12
            configuration.timeoutIntervalForResource = 20
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
    }

    func signIn(with credentials: AppleSignInCredentials) async throws -> StoredAuthSession {
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
        var request = try request(path: "auth/sign-in/social", method: "POST")
        request.httpBody = try JSONEncoder.via.encode(body)

        let (data, response) = try await perform(request)
        let bearer = try signedBearer(from: response)
        let signedIn = try JSONDecoder.via.decode(SignInResponse.self, from: data)
        guard !signedIn.user.id.isEmpty else { throw AuthenticationClientError.invalidResponse }

        let provisional = StoredAuthSession(
            bearerToken: bearer,
            user: AuthUser(
                id: signedIn.user.id,
                appleUserIdentifier: credentials.appleUserIdentifier,
                name: signedIn.user.name,
                email: signedIn.user.email
            ),
            expiresAt: .now.addingTimeInterval(30 * 24 * 60 * 60),
            lastValidatedAt: .now
        )
        return try await validate(provisional)
    }

    func validate(_ storedSession: StoredAuthSession) async throws -> StoredAuthSession {
        let request = try request(
            path: "auth/get-session",
            method: "GET",
            bearerToken: storedSession.bearerToken
        )
        let (data, response) = try await perform(request)
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
                email: envelope.user.email
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

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
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
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AuthenticationClientError.transport
        }
    }

    private func signedBearer(from response: HTTPURLResponse) throws -> String {
        guard let bearer = response.value(forHTTPHeaderField: "set-auth-token"),
              bearer.contains(".") else {
            throw AuthenticationClientError.invalidResponse
        }
        return bearer
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
}

private struct SignInResponse: Decodable {
    let user: AuthResponseUser
}

private struct SessionEnvelope: Decodable {
    struct Session: Decodable {
        let expiresAt: Date
    }

    let session: Session
    let user: AuthResponseUser
}
