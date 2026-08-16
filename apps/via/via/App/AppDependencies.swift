import Foundation

@MainActor
struct RootDependencies {
    let networkMap: NetworkViewModel
    let account: AccountModel
    let makeDeparturesViewModel: (StationID) -> DeparturesViewModel
}

@MainActor
struct AppDependencies {
    let authSession: AuthSessionViewModel
    let root: RootDependencies

    static func live(configuration: AppConfiguration) throws -> AppDependencies {
        let vault = KeychainAuthSessionVault()
        let lifecycle = AsyncStream.makeStream(of: AuthLifecycleEvent.self)
        let transport = ViaTransport(
            baseURL: configuration.apiBaseURL,
            authSessionVault: vault,
            onUnauthorized: {
                lifecycle.continuation.yield(.authenticatedRequestRejected)
            }
        )
        let account = AccountModel(
            store: AccountLocalStore(),
            remote: LiveAccountRemote(transport: transport)
        )
        let departures = LiveDeparturesRepository(transport: transport)
        return AppDependencies(
            authSession: AuthSessionViewModel(
                client: BetterAuthClient(baseURL: configuration.apiBaseURL),
                vault: vault,
                credentialStatusChecker: LiveAppleCredentialStatusChecker(),
                account: account,
                lifecycleEvents: lifecycle.stream
            ),
            root: RootDependencies(
                networkMap: NetworkViewModel(
                    repository: LiveNetworkRepository(transport: transport)
                ),
                account: account,
                makeDeparturesViewModel: { stationID in
                    DeparturesViewModel(stationID: stationID, repository: departures)
                }
            )
        )
    }

    static var preview: AppDependencies {
        let session = StoredAuthSession(
            bearerToken: "preview-token",
            user: AuthUser(
                id: "preview-user",
                appleUserIdentifier: "preview-apple-user",
                name: "Camille Martin",
                email: "camille@example.com"
            ),
            expiresAt: .distantFuture,
            lastValidatedAt: .now
        )
        let vault = InMemoryAuthSessionVault(session: session)
        let account = AccountModel(
            store: AccountLocalStore(
                defaults: UserDefaults(suiteName: "dev.via.preview")!
            ),
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false
        )
        let departures = InMemoryDeparturesRepository()
        return AppDependencies(
            authSession: AuthSessionViewModel(
                client: InMemoryAuthenticationClient(session: session),
                vault: vault,
                credentialStatusChecker: InMemoryAppleCredentialStatusChecker(),
                account: account
            ),
            root: RootDependencies(
                networkMap: NetworkViewModel(
                    repository: InMemoryNetworkRepository.mapPreview
                ),
                account: account,
                makeDeparturesViewModel: { stationID in
                    DeparturesViewModel(stationID: stationID, repository: departures)
                }
            )
        )
    }
}
