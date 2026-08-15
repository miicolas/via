import Testing
@testable import Via

struct ClientIdentityTests {
    @Test
    func importsExpoSecureStoreIdentityIntoNativeKeychain() {
        let keychain = StubClientIdentityKeychain()
        keychain.insert(
            value: "expo-identity",
            service: "app:no-auth",
            account: "via.anonymous-client-id",
            accountUsesDataAttribute: true
        )

        let store = ClientIdentityStore(keychain: keychain)

        #expect(store.identifier == "expo-identity")
        #expect(
            keychain.value(
                service: "dev.via.app",
                account: "via.anonymous-client-id",
                accountUsesDataAttribute: false
            ) == "expo-identity"
        )
    }

    @Test
    func prefersNativeIdentityAndDoesNotRewriteIt() {
        let keychain = StubClientIdentityKeychain()
        keychain.insert(
            value: "native-identity",
            service: "dev.via.app",
            account: "via.anonymous-client-id",
            accountUsesDataAttribute: false
        )
        keychain.insert(
            value: "legacy-identity",
            service: "app",
            account: "via.anonymous-client-id",
            accountUsesDataAttribute: true
        )

        let store = ClientIdentityStore(keychain: keychain)

        #expect(store.identifier == "native-identity")
        #expect(keychain.savedValues.isEmpty)
    }
}

private final class StubClientIdentityKeychain: ClientIdentityKeychain, @unchecked Sendable {
    private struct Lookup: Hashable {
        let service: String
        let account: String
        let accountUsesDataAttribute: Bool
    }

    private var values: [Lookup: String] = [:]
    private(set) var savedValues: [String] = []

    func read(
        service: String,
        account: String,
        accountUsesDataAttribute: Bool
    ) -> String? {
        values[Lookup(
            service: service,
            account: account,
            accountUsesDataAttribute: accountUsesDataAttribute
        )]
    }

    func save(value: String, service: String, account: String) {
        values[Lookup(
            service: service,
            account: account,
            accountUsesDataAttribute: false
        )] = value
        savedValues.append(value)
    }

    func insert(
        value: String,
        service: String,
        account: String,
        accountUsesDataAttribute: Bool
    ) {
        values[Lookup(
            service: service,
            account: account,
            accountUsesDataAttribute: accountUsesDataAttribute
        )] = value
    }

    func value(
        service: String,
        account: String,
        accountUsesDataAttribute: Bool
    ) -> String? {
        values[Lookup(
            service: service,
            account: account,
            accountUsesDataAttribute: accountUsesDataAttribute
        )]
    }
}
