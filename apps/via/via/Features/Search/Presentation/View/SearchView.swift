import SwiftUI

/// Content of the dedicated search tab. A destination result immediately
/// becomes a journey request; the map remains visible behind the sheet.
@MainActor
struct SearchView: View {
    let viewModel: SearchViewModel
    let activeJourneyModel: ActiveJourneyModel
    let onClose: () -> Void
    let onInspectJourney: (Journey) -> Void
    let onShowActiveJourney: () -> Void

    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var inputTransitionNamespace
    @State private var isDeparturePickerPresented = false
    @State private var isNaturalDatePickerPresented = false
    @State private var isNaturalOptionsPresented = false
    @State private var isAccessibilityInfoPresented = false

    init(
        viewModel: SearchViewModel,
        activeJourneyModel: ActiveJourneyModel,
        onClose: @escaping () -> Void = {},
        onInspectJourney: @escaping (Journey) -> Void = { _ in },
        onShowActiveJourney: @escaping () -> Void = {},
    ) {
        self.viewModel = viewModel
        self.activeJourneyModel = activeJourneyModel
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
                    ToolbarItem(placement: .topBarTrailing) {
                        searchFiltersMenu
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
    }

    private var searchFiltersMenu: some View {
        SearchFiltersMenu(
            filters: viewModel.filters,
            onSetRequiresAccessibleStations: { isEnabled in
                viewModel.setRequiresAccessibleStations(isEnabled)
            },
            onShowAccessibilityInfo: {
                isAccessibilityInfoPresented = true
            }
        )
    }

    private var hasActiveJourneySurface: Bool {
        activeJourneyModel.isActive || activeJourneyModel.arrival != nil
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

                Text(viewModel.wrappedValue.selectedDeparture.title)
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityLabel("Point de départ")
        .accessibilityValue(viewModel.wrappedValue.selectedDeparture.title)
        .accessibilityHint("Ouvre le menu pour choisir un point de départ")
    }

    private func searchContent(viewModel: Bindable<SearchViewModel>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                inputStage(viewModel: viewModel)

                if let criteria = viewModel.wrappedValue.naturalJourneyCriteria,
                   viewModel.wrappedValue.step != .destination
                {
                    NaturalJourneyCriteriaView(
                        criteria: criteria,
                        journeyCount: viewModel.wrappedValue.journeyResult?.journeys.count ?? 0,
                        onEditOrigin: { isDeparturePickerPresented = true },
                        onEditDestination: viewModel.wrappedValue.editDestination,
                        onEditTime: { isNaturalDatePickerPresented = true },
                        onEditOptions: { isNaturalOptionsPresented = true },
                    )
                }

                if viewModel.wrappedValue.step == .destination {
                    SearchResultsSection(
                        state: viewModel.wrappedValue.loadState,
                        results: viewModel.wrappedValue.results,
                        onRetry: viewModel.wrappedValue.retry,
                        onSelect: viewModel.wrappedValue.selectDestination,
                    )
                } else if let destination = viewModel.wrappedValue.selectedDestination {
                    SearchJourneyResultsView(
                        step: viewModel.wrappedValue.step,
                        result: viewModel.wrappedValue.journeyResult,
                        destinationName: destination.name,
                        departureTitle: viewModel.wrappedValue.selectedDeparture.title,
                        selectedJourneyID: viewModel.wrappedValue.selectedJourneyID,
                        onSelectJourney: { journey in
                            viewModel.wrappedValue.selectJourney(journey)
                            onInspectJourney(journey)
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
