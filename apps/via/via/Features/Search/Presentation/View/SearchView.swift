import SwiftUI
import UIKit

/// Content of the dedicated search tab. A destination result immediately
/// becomes a journey request; the map remains visible behind the sheet.
@MainActor
struct SearchView: View {
    let viewModel: SearchViewModel
    let activeJourneyModel: ActiveJourneyModel
    let journeyNotificationCoordinator: JourneyNotificationCoordinator
    let onClose: () -> Void
    let onInspectJourney: (Journey) -> Void
    let onShowActiveJourney: () -> Void

    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @Namespace private var inputTransitionNamespace
    @State private var isDeparturePickerPresented = false
    @State private var isNaturalDatePickerPresented = false
    @State private var isNaturalOptionsPresented = false
    @State private var isAccessibilityInfoPresented = false
    @State private var isClearRecentsConfirmationPresented = false
    @State private var isReminderErrorPresented = false

    init(
        viewModel: SearchViewModel,
        activeJourneyModel: ActiveJourneyModel,
        journeyNotificationCoordinator: JourneyNotificationCoordinator = .preview,
        onClose: @escaping () -> Void = {},
        onInspectJourney: @escaping (Journey) -> Void = { _ in },
        onShowActiveJourney: @escaping () -> Void = {},
    ) {
        self.viewModel = viewModel
        self.activeJourneyModel = activeJourneyModel
        self.journeyNotificationCoordinator = journeyNotificationCoordinator
        self.onClose = onClose
        self.onInspectJourney = onInspectJourney
        self.onShowActiveJourney = onShowActiveJourney
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            searchContent(viewModel: $viewModel)
                .navigationTitle("Recherche")
                .navigationSubtitle(viewModel.subtitle)
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbar {
                    ToolbarItem(placement: .largeSubtitle) {
                        departureMenu(viewModel: $viewModel)
                    }
                    ToolbarItem(placement: .subtitle) {
                        departureMenu(viewModel: $viewModel)
                    }
                    activeJourneyToolbarItem
                    if viewModel.canResetSearch {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Nouvelle recherche", systemImage: "arrow.counterclockwise") {
                                viewModel.resetSearch()
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityHint("Efface le trajet et le point de départ sélectionnés")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            onClose()
                        }
                    }
                }
        }
        .opacity(tabVisibilityProgress)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .sheet(isPresented: $isDeparturePickerPresented) {
            SearchDeparturePickerView(
                viewModel: viewModel,
                savedPlaces: viewModel.savedPlaces,
                selection: viewModel.selectedDeparture,
                onSelect: viewModel.selectDeparture,
            )
        }
        .sheet(isPresented: $isNaturalDatePickerPresented) {
            if let criteria = viewModel.naturalJourneyCriteria {
                NaturalJourneyDatePickerView(
                    initialDate: criteria.requestedAt,
                    initialMeaning: criteria.datetimeRepresents,
                    onApply: viewModel.updateNaturalTime,
                )
            } else {
                NaturalJourneyDatePickerView(
                    initialDate: viewModel.requestedAt ?? .now,
                    initialMeaning: viewModel.datetimeRepresents,
                    onApply: viewModel.updateTime,
                )
            }
        }
        .sheet(isPresented: $isNaturalOptionsPresented) {
            if let criteria = viewModel.naturalJourneyCriteria {
                NaturalJourneyOptionsView(
                    required: criteria.requiredModes,
                    excluded: criteria.excludedModes,
                    preferred: criteria.preferredModes,
                    onApply: viewModel.updateNaturalModes,
                )
            }
        }
        .sheet(isPresented: $isAccessibilityInfoPresented) {
            SearchAccessibilityInfoView(source: viewModel.accessibilitySource)
        }
        .confirmationDialog(
            "Effacer les recherches récentes ?",
            isPresented: $isClearRecentsConfirmationPresented,
            titleVisibility: .visible,
        ) {
            Button("Effacer les recherches récentes", role: .destructive) {
                viewModel.clearRecentSearches()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action supprime les destinations enregistrées sur cet appareil.")
        }
        .alert("Rappel non modifié", isPresented: $isReminderErrorPresented) {
            if journeyNotificationCoordinator.authorizationStatus == .denied {
                Button("Ouvrir les réglages iOS") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                journeyNotificationCoordinator.lastError ??
                    "Votre rappel est mémorisé et sera réessayé plus tard."
            )
        }
    }

    private var hasActiveJourneySurface: Bool {
        activeJourneyModel.hasSurface
    }

    @ToolbarContentBuilder
    private var activeJourneyToolbarItem: some ToolbarContent {
        if hasActiveJourneySurface {
            ToolbarItem(placement: .topBarLeading) {
                Button("Trajet actif", systemImage: "location.fill") {
                    onShowActiveJourney()
                }
            }
        }
    }

    private func departureMenu(viewModel: Bindable<SearchViewModel>) -> some View {
        Menu {
            SearchDepartureMenuContent(
                selection: viewModel.wrappedValue.selectedDeparture,
                savedPlaces: viewModel.wrappedValue.savedPlaces,
                onSelect: viewModel.wrappedValue.selectDeparture,
                onChooseManual: { isDeparturePickerPresented = true },
            )
        } label: {
            HStack(spacing: 4) {
                Text("Depuis ")
                    .foregroundStyle(.secondary)
                    .fixedSize()

                Text(viewModel.wrappedValue.selectedDeparture.title)
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize()
            }
        }
        .accessibilityLabel("Point de départ")
        .accessibilityValue(viewModel.wrappedValue.selectedDeparture.title)
        .accessibilityHint("Ouvre le menu pour choisir un point de départ")
    }

    private func searchContent(viewModel: Bindable<SearchViewModel>) -> some View {
        Group {
            if viewModel.wrappedValue.step == .destination {
                destinationSearchContent(viewModel: viewModel)
            } else {
                journeySearchContent(viewModel: viewModel)
            }
        }
    }

    private func destinationSearchContent(viewModel: Bindable<SearchViewModel>) -> some View {
        List {
            inputStage(viewModel: viewModel)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if viewModel.wrappedValue.naturalJourneyCriteria == nil {
                SearchOptionsBar(
                    requestedAt: viewModel.wrappedValue.requestedAt,
                    datetimeRepresents: viewModel.wrappedValue.datetimeRepresents,
                    requiresAccessibleStations: viewModel.wrappedValue.filters.requiresAccessibleStations,
                    onEditTime: { isNaturalDatePickerPresented = true },
                    onToggleAccessibleStations: {
                        viewModel.wrappedValue.setRequiresAccessibleStations(
                            !viewModel.wrappedValue.filters.requiresAccessibleStations
                        )
                    },
                    onShowAccessibilityInfo: { isAccessibilityInfoPresented = true },
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if viewModel.wrappedValue.showsRecentSearches {
                Section {
                    ForEach(viewModel.wrappedValue.recentSearches) { recent in
                        SearchResultRow(
                            result: recent.searchResult,
                            accessibilityHint: "Relance un trajet vers cette destination",
                        ) {
                            viewModel.wrappedValue.selectRecentSearch(recent)
                        } onDelete: {
                            viewModel.wrappedValue.removeRecentSearch(id: recent.id)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Supprimer", systemImage: "trash", role: .destructive) {
                                viewModel.wrappedValue.removeRecentSearch(id: recent.id)
                            }
                            .labelStyle(.iconOnly)
                        }
                    }
                } header: {
                    HStack {
                        Text("Récentes")

                        Spacer()

                        Button("Tout effacer", systemImage: "trash", role: .destructive) {
                            isClearRecentsConfirmationPresented = true
                        }
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityHint("Demande confirmation avant de supprimer tout l’historique local")
                    }
                }
            }

            if viewModel.wrappedValue.loadState != .idle {
                Section {
                    SearchResultsSection(
                        state: viewModel.wrappedValue.loadState,
                        results: viewModel.wrappedValue.results,
                        onRetry: viewModel.wrappedValue.retry,
                        onSelect: viewModel.wrappedValue.selectDestination,
                    )
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .animation(inputAnimation, value: viewModel.wrappedValue.step)
    }

    private func journeySearchContent(viewModel: Bindable<SearchViewModel>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                inputStage(viewModel: viewModel)

                if let criteria = viewModel.wrappedValue.naturalJourneyCriteria {
                    NaturalJourneyCriteriaView(
                        criteria: criteria,
                        journeyCount: viewModel.wrappedValue.journeyResult?.journeys.count ?? 0,
                        onEditOrigin: { isDeparturePickerPresented = true },
                        onEditDestination: viewModel.wrappedValue.editDestination,
                        onEditTime: { isNaturalDatePickerPresented = true },
                        onEditOptions: { isNaturalOptionsPresented = true },
                    )
                } else if viewModel.wrappedValue.step == .results {
                    SearchOptionsBar(
                        requestedAt: viewModel.wrappedValue.requestedAt,
                        datetimeRepresents: viewModel.wrappedValue.datetimeRepresents,
                        requiresAccessibleStations: viewModel.wrappedValue.filters.requiresAccessibleStations,
                        onEditTime: { isNaturalDatePickerPresented = true },
                        onToggleAccessibleStations: {
                            viewModel.wrappedValue.setRequiresAccessibleStations(
                                !viewModel.wrappedValue.filters.requiresAccessibleStations
                            )
                        },
                        onShowAccessibilityInfo: { isAccessibilityInfoPresented = true },
                    )
                }

                if viewModel.wrappedValue.selectedDestination != nil {
                    SearchJourneyResultsView(
                        step: viewModel.wrappedValue.step,
                        result: viewModel.wrappedValue.journeyResult,
                        selectedJourneyID: viewModel.wrappedValue.selectedJourneyID,
                        scheduledReminderJourneyID: journeyNotificationCoordinator.scheduledJourneyID,
                        reminderLeadTime: journeyNotificationCoordinator.preferences.departureLeadTime,
                        isUpdatingReminder: journeyNotificationCoordinator.isUpdatingReminder,
                        onSelectJourney: { journey in
                            viewModel.wrappedValue.selectJourney(journey)
                            onInspectJourney(journey)
                        },
                        onScheduleReminder: { journey, leadTime in
                            guard let destination = viewModel.wrappedValue.journeyDestination else { return }
                            let source = viewModel.wrappedValue.journeyResult?.source
                            Task {
                                if journeyNotificationCoordinator.preferences.departureLeadTime != leadTime {
                                    await journeyNotificationCoordinator.updateDepartureLeadTime(leadTime)
                                    guard journeyNotificationCoordinator.preferences.departureLeadTime == leadTime else {
                                        isReminderErrorPresented = true
                                        return
                                    }
                                }
                                await journeyNotificationCoordinator.scheduleReminder(
                                    for: journey,
                                    destination: destination,
                                    source: source
                                )
                                isReminderErrorPresented = journeyNotificationCoordinator.lastError != nil
                            }
                        },
                        onCancelReminder: {
                            Task {
                                await journeyNotificationCoordinator.cancelReminder()
                                isReminderErrorPresented = journeyNotificationCoordinator.lastError != nil
                            }
                        },
                        onRetry: viewModel.wrappedValue.retryJourney,
                        onEdit: viewModel.wrappedValue.editDestination,
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .animation(inputAnimation, value: viewModel.wrappedValue.step)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func inputStage(viewModel: Bindable<SearchViewModel>) -> some View {
        let step = viewModel.wrappedValue.step

        if step == .destination {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    SearchDestinationField(
                        text: viewModel.query,
                        onClear: viewModel.wrappedValue.clearQuery,
                        onSubmit: viewModel.wrappedValue.searchImmediately,
                    )
                    .onChange(of: viewModel.wrappedValue.query) { _, newValue in
                        viewModel.wrappedValue.updateQuery(newValue)
                    }

                    if viewModel.wrappedValue.naturalLanguageAccess != .hidden {
                        AIEntryButton(
                            isDiscoverable: viewModel.wrappedValue.showsNaturalSearchDiscovery,
                        ) {
                            viewModel.wrappedValue.openNaturalSearch()
                        }
                    }
                }
            }
            .matchedGeometryEffect(
                id: destinationInputID,
                in: inputTransitionNamespace,
                properties: .frame,
                anchor: .leading,
            )
            .transition(.identity)
        } else {
            destinationToken(viewModel: viewModel)
                .matchedGeometryEffect(
                    id: destinationInputID,
                    in: inputTransitionNamespace,
                    properties: .frame,
                    anchor: .leading,
                )
                .transition(.identity)
        }
    }

    @ViewBuilder
    private func destinationToken(viewModel: Bindable<SearchViewModel>) -> some View {
        if let destination = viewModel.wrappedValue.selectedDestination {
            SearchInputToken(
                title: destination.name,
                subtitle: destination.searchTokenSubtitle,
                systemImage: destination.searchTokenSystemImage,
                accessibilityLabel: "Destination \(destination.name)",
                expands: true,
                action: viewModel.wrappedValue.editDestination,
            )
        }
    }

    private var inputAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.35, extraBounce: 0.02)
    }

    private var destinationInputID: String { "search-destination-input" }
}

private extension SearchResult {
    var searchTokenSubtitle: String? {
        switch self {
        case let .station(station):
            let routes = station.routes.prefix(3).map(\.shortName).joined(separator: " · ")
            return routes.isEmpty ? "Station" : routes
        case let .address(address):
            return address.context.isEmpty ? "Adresse" : address.context
        }
    }

    var searchTokenSystemImage: String {
        switch self {
        case let .station(station):
            station.routes.first?.mode.chipSystemImage ?? "tram.fill"
        case .address:
            "mappin.and.ellipse"
        }
    }
}

#Preview("Destination") {
    let locationModel = LocationModel(adapter: InMemoryLocationAdapter())
    SearchView(
        viewModel: SearchViewModel(
            repository: InMemorySearchRepository.preview,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
            locationModel: locationModel,
        ),
        activeJourneyModel: ActiveJourneyModel(
            locationModel: locationModel,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
        ),
    )
}
