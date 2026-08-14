import Testing
@testable import Via

struct NativeRuntimeConfigurationTests {
    @Test
    func testDebugArgumentsEnableDeterministicDemoAndDisableFlags() {
        let configuration = NativeRuntimeConfiguration.make(
            environment: ["VIA_API_URL": "https://staging.example.com"],
            arguments: ["Via", "--via-demo", "--via-disable-chat", "--via-diagnostics"],
            allowLocalOverrides: true
        )

        #expect(configuration.apiBaseURL.absoluteString == "https://staging.example.com")
        #expect(configuration.featureFlags.usesDemoData)
        #expect(!configuration.featureFlags.chatEnabled)
        #expect(configuration.featureFlags.classicJourneysEnabled)
        #expect(configuration.featureFlags.verboseLoggingEnabled)
    }

    @Test
    func testEnvironmentFlagsOverrideLaunchDefaults() {
        let flags = NativeFeatureFlags.live(
            environment: [
                "VIA_FEATURE_CHAT": "off",
                "VIA_FEATURE_CLASSIC_JOURNEYS": "0",
                "VIA_DEMO_DATA": "yes",
                "VIA_DIAGNOSTICS": "true",
            ],
            arguments: [],
            allowLocalOverrides: true
        )

        #expect(!flags.chatEnabled)
        #expect(!flags.classicJourneysEnabled)
        #expect(flags.usesDemoData)
        #expect(flags.verboseLoggingEnabled)
    }

    @Test
    func releaseConfigurationIgnoresLocalOverrides() {
        let flags = NativeFeatureFlags.live(
            environment: ["VIA_DEMO_DATA": "1"],
            arguments: ["--via-demo"],
            allowLocalOverrides: false
        )

        #expect(flags == NativeFeatureFlags())
    }

    @Test
    func testInvalidAPIURLFallsBackToLocalDevelopmentServer() {
        let configuration = NativeRuntimeConfiguration.make(
            environment: ["VIA_API_URL": "not a url"],
            arguments: []
        )

        #expect(configuration.apiBaseURL == NativeRuntimeConfiguration.defaultAPIURL)
    }
}
