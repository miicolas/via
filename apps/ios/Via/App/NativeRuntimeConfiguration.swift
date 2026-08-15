import Foundation

struct NativeFeatureFlags: Equatable, Sendable {
    let chatEnabled: Bool
    let classicJourneysEnabled: Bool
    let naturalJourneysEnabled: Bool
    let usesDemoData: Bool
    let verboseLoggingEnabled: Bool

    init(
        chatEnabled: Bool = true,
        classicJourneysEnabled: Bool = true,
        naturalJourneysEnabled: Bool = true,
        usesDemoData: Bool = false,
        verboseLoggingEnabled: Bool = false
    ) {
        self.chatEnabled = chatEnabled
        self.classicJourneysEnabled = classicJourneysEnabled
        self.naturalJourneysEnabled = naturalJourneysEnabled
        self.usesDemoData = usesDemoData
        self.verboseLoggingEnabled = verboseLoggingEnabled
    }

    static func live(
        environment: [String: String],
        arguments: [String],
        allowLocalOverrides: Bool = localOverridesEnabled
    ) -> NativeFeatureFlags {
        guard allowLocalOverrides else {
            return NativeFeatureFlags()
        }

        return NativeFeatureFlags(
            chatEnabled: environment.boolean(named: "VIA_FEATURE_CHAT")
                ?? !arguments.contains("--via-disable-chat"),
            classicJourneysEnabled: environment.boolean(named: "VIA_FEATURE_CLASSIC_JOURNEYS")
                ?? !arguments.contains("--via-disable-classic-journeys"),
            naturalJourneysEnabled: environment.boolean(named: "VIA_FEATURE_NATURAL_JOURNEYS")
                ?? !arguments.contains("--via-disable-natural-journeys"),
            usesDemoData: environment.boolean(named: "VIA_DEMO_DATA")
                ?? arguments.contains("--via-demo"),
            verboseLoggingEnabled: environment.boolean(named: "VIA_DIAGNOSTICS")
                ?? arguments.contains("--via-diagnostics")
        )
    }

    #if DEBUG || STAGING
    static let localOverridesEnabled = true
    #else
    static let localOverridesEnabled = false
    #endif
}

struct NativeRuntimeConfiguration: Equatable, Sendable {
    static let defaultAPIURL = URL(string: "http://localhost:3000")!

    let apiBaseURL: URL
    let featureFlags: NativeFeatureFlags

    static func live(processInfo: ProcessInfo = .processInfo) -> NativeRuntimeConfiguration {
        make(
            environment: processInfo.environment,
            arguments: processInfo.arguments
        )
    }

    static func make(
        environment: [String: String],
        arguments: [String],
        allowLocalOverrides: Bool = NativeFeatureFlags.localOverridesEnabled
    ) -> NativeRuntimeConfiguration {
        let apiBaseURL = environment["VIA_API_URL"].flatMap { value in
            guard let url = URL(string: value),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  url.host != nil
            else { return nil }
            return url
        }
            ?? defaultAPIURL

        return NativeRuntimeConfiguration(
            apiBaseURL: apiBaseURL,
            featureFlags: .live(
                environment: environment,
                arguments: arguments,
                allowLocalOverrides: allowLocalOverrides
            )
        )
    }
}

private extension Dictionary where Key == String, Value == String {
    func boolean(named key: String) -> Bool? {
        guard let value = self[key]?.lowercased() else { return nil }
        switch value {
        case "1", "true", "yes", "on": return true
        case "0", "false", "no", "off": return false
        default: return nil
        }
    }
}
