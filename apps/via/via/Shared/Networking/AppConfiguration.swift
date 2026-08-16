import Foundation

struct AppConfiguration: Sendable {
    let apiBaseURL: URL

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

        return AppConfiguration(apiBaseURL: url)
    }
}

