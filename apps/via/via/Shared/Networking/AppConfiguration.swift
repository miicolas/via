import Foundation

enum APNsEnvironment: String, Codable, Sendable {
    case sandbox
    case production
}

struct AppConfiguration: Sendable, Hashable {
    let apiBaseURL: URL
    let bundleIdentifier: String
    let apnsEnvironment: APNsEnvironment
    /// Shared secret naming this build as a first-party caller. The API refuses
    /// anyone who cannot present it, which is what keeps the transit contract
    /// and its upstream quotas from being a public service. It ships inside the
    /// binary and is therefore extractable — it raises the cost of cloning the
    /// client, it never stands in for a session. `nil` when the build has no
    /// `Configuration/Secrets.xcconfig`, which is the local-API case.
    let apiClientKey: String?

    static func bundled(bundle: Bundle = .main) throws -> AppConfiguration {
        guard
            let rawValue = bundle.object(forInfoDictionaryKey: "VIA_API_BASE_URL") as? String,
            let url = URL(string: rawValue),
            url.host != nil
        else {
            throw ViaError.invalidConfiguration("VIA_API_BASE_URL est absente ou invalide")
        }

        #if RELEASE
        guard url.scheme == "https", url.host?.hasSuffix(".invalid") == false else {
            throw ViaError.invalidConfiguration("L’URL de production doit être une URL HTTPS réelle")
        }
        #endif

        let apiClientKey = (bundle.object(forInfoDictionaryKey: "VIA_API_CLIENT_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let rawEnvironment =
            bundle.object(forInfoDictionaryKey: "VIA_APNS_ENVIRONMENT") as? String ?? "sandbox"
        guard let apnsEnvironment = APNsEnvironment(rawValue: rawEnvironment) else {
            throw ViaError.invalidConfiguration("VIA_APNS_ENVIRONMENT est invalide")
        }

        return AppConfiguration(
            apiBaseURL: url,
            bundleIdentifier: bundle.bundleIdentifier ?? "dev.via.app",
            apnsEnvironment: apnsEnvironment,
            apiClientKey: apiClientKey?.isEmpty == false ? apiClientKey : nil
        )
    }
}
