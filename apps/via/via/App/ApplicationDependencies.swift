import Foundation

/// All application-wide adapters are assembled in one place. The app entry
/// point owns lifecycle and view composition; this module owns preview/live
/// wiring so the two environments cannot drift field by field.
@MainActor
struct ApplicationDependencies {
    let locationModel: LocationModel
    let networkRepository: any NetworkRepository
    let departuresRepository: any DeparturesRepository
    let stationCrowdingRepository: any StationCrowdingRepository
    let searchRepository: any SearchRepository
    let reportRepository: any ReportRepository
    let activeJourneyStore: any ActiveJourneyStore
    let plannedJourneyDraftStore: any PlannedJourneyDraftStoring
    let activityManager: any JourneyActivityManaging
    let connectivityMonitor: any ConnectivityMonitoring
    let journeyRepository: any JourneyRepository
    let journeyShareRepository: any JourneyShareRepository
    let journeyDepartureChoicesRepository: any JourneyDepartureChoicesRepository
    let naturalJourneyRepository: any NaturalJourneyRepository
    let naturalLanguageAvailability: @Sendable () -> NaturalLanguageAvailability
    let naturalJourneyMetrics: any NaturalJourneyMetricsRecording
    let lineStatusRepository: any LineStatusRepository
    let accountModel: AccountModel
    let authSessionViewModel: AuthSessionViewModel
    let onboardingModel: OnboardingModel
    let onboardingProfileModel: OnboardingProfileModel
    let pushNotificationManager: PushNotificationManager
    let journeyNotificationCoordinator: JourneyNotificationCoordinator
    let notificationInboxRemote: any NotificationInboxRemote
}

@MainActor
enum ApplicationDependencyFactory {
    static func make(pushNotificationManager: PushNotificationManager) -> ApplicationDependencies {
        guard let configuration = try? AppConfiguration.bundled() else {
            let accountModel = AccountModel(
                remote: InMemoryAccountRemote(),
                synchronizationEnabled: false,
            )
            accountModel.activateAnonymous()
            let previewSession = StoredAuthSession(
                bearerToken: "preview.token",
                user: AuthUser(
                    id: "preview",
                    appleUserIdentifier: "preview",
                    name: "Preview",
                    email: "preview@example.com",
                ),
                expiresAt: .distantFuture,
                lastValidatedAt: .now,
            )

            return ApplicationDependencies(
                locationModel: LocationModel(
                    adapter: InMemoryLocationAdapter(
                        coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470),
                    ),
                ),
                networkRepository: InMemoryNetworkRepository.mapPreview,
                departuresRepository: InMemoryDeparturesRepository.stationsPreview,
                stationCrowdingRepository: InMemoryStationCrowdingRepository(
                    crowding: .preview
                ),
                searchRepository: InMemorySearchRepository.preview,
                reportRepository: InMemoryReportRepository(),
                activeJourneyStore: InMemoryActiveJourneyStore(),
                plannedJourneyDraftStore: InMemoryPlannedJourneyDraftStore(),
                activityManager: NoOpJourneyActivityManager(),
                connectivityMonitor: InMemoryConnectivityMonitor(),
                journeyRepository: PreferenceAwareJourneyRepository(
                    base: InMemoryJourneyRepository(result: .mapPreview),
                    account: accountModel,
                ),
                journeyShareRepository: InMemoryJourneyShareRepository(),
                journeyDepartureChoicesRepository: InMemoryJourneyDepartureChoicesRepository.unavailable,
                naturalJourneyRepository: InMemoryNaturalJourneyRepository(),
                naturalLanguageAvailability: { .available },
                naturalJourneyMetrics: NoOpNaturalJourneyMetrics(),
                lineStatusRepository: PreviewLineStatusRepository(),
                accountModel: accountModel,
                authSessionViewModel: AuthSessionViewModel(
                    client: InMemoryAuthenticationClient(session: previewSession),
                    vault: InMemoryAuthSessionVault(),
                    account: accountModel,
                    onAuthenticatedSessionEnded: {
                        await pushNotificationManager.unregisterCurrentInstallation()
                        await pushNotificationManager.setAuthenticated(false)
                    },
                ),
                onboardingModel: OnboardingModel(),
                onboardingProfileModel: OnboardingProfileModel(),
                pushNotificationManager: pushNotificationManager,
                journeyNotificationCoordinator: JourneyNotificationCoordinator(
                    activeJourneyManager: pushNotificationManager
                ),
                notificationInboxRemote: NoOpNotificationInboxRemote(),
            )
        }

        // Product endpoints remain usable anonymously; 401 events still invalidate a cached session.
        let authSessionVault = KeychainAuthSessionVault(apiBaseURL: configuration.apiBaseURL)
        let (unauthorizedEvents, unauthorizedContinuation) = AsyncStream<String>.makeStream()
        let transport = APITransport(
            baseURL: configuration.apiBaseURL,
            authSessionVault: authSessionVault,
            clientKey: configuration.apiClientKey,
            onUnauthorized: { rejectedBearerToken in
                unauthorizedContinuation.yield(rejectedBearerToken)
            },
        )
        pushNotificationManager.configure(
            configuration: configuration,
            remote: LivePushNotificationRemote(transport: transport)
        )
        let accountModel = AccountModel(remote: LiveAccountRemote(transport: transport))
        accountModel.activateAnonymous()
        let journeyRepository = PreferenceAwareJourneyRepository(
            base: LocalAlternativesJourneyRepository(
                base: LiveJourneyRepository(transport: transport),
                direct: MapKitDirectJourneyRouter(),
            ),
            account: accountModel,
        )
        let journeyShareRepository = LiveJourneyShareRepository(transport: transport)
        let searchRepository = LiveSearchRepository(transport: transport)
        let lineStatusRepository = LiveLineStatusRepository(transport: transport)
        let naturalIntentParser = FoundationModelsIntentParser()
        let naturalJourneyMetrics = AppLogNaturalJourneyMetrics()
        let naturalJourneyUnderstanding = ReliableNaturalJourneyUnderstanding(
            localModel: naturalIntentParser,
            remoteModel: RemoteNaturalIntentParser(transport: transport),
            savedPlaces: {
                await MainActor.run {
                    let roles = SavedPlace.Role.allCases.map { role in
                        let place = accountModel.place(for: role)
                        return NaturalJourneySavedPlaceReference(
                            id: "role:\(role.rawValue)",
                            label: role.displayTitle,
                            kind: role == .home ? .home : .work,
                            result: place?.searchResult,
                        )
                    }
                    let custom = accountModel.destinations.map { destination in
                        NaturalJourneySavedPlaceReference(
                            id: "custom:\(destination.id.uuidString)",
                            label: destination.label,
                            kind: .custom,
                            result: destination.searchResult,
                        )
                    }
                    return roles + custom
                }
            },
            serverFallbackAllowed: {
                NaturalJourneyProcessingPreference.allowsServerFallback()
            },
        )
        let onDeviceNaturalJourneyService = OnDeviceNaturalJourneyService(
            understanding: naturalJourneyUnderstanding,
            places: OnDevicePlaceResolver { query, coordinate in
                try await searchRepository.search(query: query, near: coordinate)
            },
            journeys: journeyRepository,
            lineStatuses: lineStatusRepository,
            metrics: naturalJourneyMetrics,
            requiresAccessibleStations: {
                UserDefaultsSearchFilterStore().load().requiresAccessibleStations
            },
            requiresOperationalElevators: {
                UserDefaultsSearchFilterStore().load().requiresOperationalElevators
            },
            favorites: { role in
                await MainActor.run { accountModel.place(for: role)?.searchResult }
            },
        )
        let naturalJourneyRepository = onDeviceNaturalJourneyService

        return ApplicationDependencies(
            locationModel: LocationModel(adapter: CoreLocationAdapter()),
            networkRepository: LiveNetworkRepository(transport: transport),
            departuresRepository: LiveDeparturesRepository(transport: transport),
            stationCrowdingRepository: LiveStationCrowdingRepository(transport: transport),
            searchRepository: searchRepository,
            reportRepository: LiveReportRepository(transport: transport),
            activeJourneyStore: UserDefaultsActiveJourneyStore(),
            plannedJourneyDraftStore: UserDefaultsPlannedJourneyDraftStore(),
            activityManager: JourneyActivityManager(),
            connectivityMonitor: NetworkConnectivityMonitor(),
            journeyRepository: journeyRepository,
            journeyShareRepository: journeyShareRepository,
            journeyDepartureChoicesRepository: LiveJourneyDepartureChoicesRepository(
                transport: transport
            ),
            naturalJourneyRepository: naturalJourneyRepository,
            naturalLanguageAvailability: { naturalJourneyUnderstanding.availability },
            naturalJourneyMetrics: naturalJourneyMetrics,
            lineStatusRepository: lineStatusRepository,
            accountModel: accountModel,
            authSessionViewModel: AuthSessionViewModel(
                client: BetterAuthClient(
                    baseURL: configuration.apiBaseURL,
                    clientKey: configuration.apiClientKey
                ),
                vault: authSessionVault,
                account: accountModel,
                unauthorizedEvents: unauthorizedEvents,
                onAuthenticatedSessionEnded: {
                    await pushNotificationManager.unregisterCurrentInstallation()
                    await pushNotificationManager.setAuthenticated(false)
                },
            ),
            onboardingModel: OnboardingModel(),
            onboardingProfileModel: OnboardingProfileModel(),
            pushNotificationManager: pushNotificationManager,
            journeyNotificationCoordinator: JourneyNotificationCoordinator(
                activeJourneyManager: pushNotificationManager
            ),
            notificationInboxRemote: LiveNotificationInboxRemote(transport: transport),
        )
    }
}
