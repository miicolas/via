import SwiftUI

/// Content of the dedicated search tab. A destination result immediately
/// becomes a journey request; the map remains visible behind the sheet.
@MainActor
struct SearchView: View {
    let viewModel: SearchViewModel
    let activeJourneyModel: ActiveJourneyModel
    let onClose: () -> Void
    let onExpandJourneyMap: () -> Void
    let onOpenReport: () -> Void

    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var inputTransitionNamespace
    @State private var isDeparturePickerPresented = false
    @State private var inspectedJourney: Journey?
    @State private var isActiveJourneyPresented = false

    init(
        viewModel: SearchViewModel,
        activeJourneyModel: ActiveJourneyModel,
        onClose: @escaping () -> Void = {},
        onExpandJourneyMap: @escaping () -> Void = {},
        onOpenReport: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.activeJourneyModel = activeJourneyModel
        self.onClose = onClose
        self.onExpandJourneyMap = onExpandJourneyMap
        self.onOpenReport = onOpenReport
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
                    if hasActiveJourneySurface {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Trajet actif", systemImage: "location.fill") {
                                isActiveJourneyPresented = true
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            onClose()
                        }
                    }
                }
                .navigationDestination(item: $inspectedJourney) { journey in
                    if let destination = viewModel.journeyDestination {
                        JourneyDetailView(
                            journey: journey,
                            destination: destination,
                            source: viewModel.journeyResult?.source,
                            activeJourneyModel: activeJourneyModel,
                            onHighlightSection: viewModel.highlightJourneySection,
                            onExpandMap: onExpandJourneyMap
                        )
                    }
                }
                .navigationDestination(isPresented: $isActiveJourneyPresented) {
                    activeJourneyDestination
                }
        }
        .opacity(tabVisibilityProgress)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .sheet(isPresented: $isDeparturePickerPresented) {
            SearchDeparturePickerView(
                viewModel: viewModel,
                savedPlaces: viewModel.savedPlaces,
                selection: viewModel.selectedDeparture,
                onSelect: viewModel.selectDeparture
            )
        }
        .onAppear(perform: synchronizeActiveJourneyPresentation)
        .onChange(of: activeJourneyModel.session?.journey.id) { _, _ in
            synchronizeActiveJourneyPresentation()
        }
        .onChange(of: activeJourneyModel.arrival?.journeyID) { _, _ in
            synchronizeActiveJourneyPresentation()
        }
    }

    @ViewBuilder
    private var activeJourneyDestination: some View {
        if let arrival = activeJourneyModel.arrival {
            JourneyArrivalView(
                arrival: arrival,
                onComplete: activeJourneyModel.completeArrival
            )
        } else if activeJourneyModel.isActive {
            ActiveJourneyPanelView(
                model: activeJourneyModel,
                onOpenReport: onOpenReport
            )
        }
    }

    private var hasActiveJourneySurface: Bool {
        activeJourneyModel.isActive || activeJourneyModel.arrival != nil
    }

    private func synchronizeActiveJourneyPresentation() {
        isActiveJourneyPresented = hasActiveJourneySurface
    }

    private func departureMenu(viewModel: Bindable<SearchViewModel>) -> some View {
        Menu {
            SearchDepartureMenuContent(
                selection: viewModel.wrappedValue.selectedDeparture,
                savedPlaces: viewModel.wrappedValue.savedPlaces,
                onSelect: viewModel.wrappedValue.selectDeparture,
                onChooseManual: { isDeparturePickerPresented = true }
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

                if viewModel.wrappedValue.step == .destination {
                    SearchResultsSection(
                        state: viewModel.wrappedValue.loadState,
                        results: viewModel.wrappedValue.results,
                        onRetry: viewModel.wrappedValue.retry,
                        onSelect: viewModel.wrappedValue.selectDestination
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
                            inspectedJourney = journey
                        },
                        onRetry: viewModel.wrappedValue.retryJourney,
                        onEdit: viewModel.wrappedValue.editDestination
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
            SearchDestinationField(
                text: viewModel.query,
                onClear: viewModel.wrappedValue.clearQuery,
                onSubmit: viewModel.wrappedValue.searchImmediately
            )
            .onChange(of: viewModel.wrappedValue.query) { _, newValue in
                viewModel.wrappedValue.updateQuery(newValue)
            }
            .matchedGeometryEffect(
                id: destinationInputID,
                in: inputTransitionNamespace,
                properties: .frame,
                anchor: .leading
            )
            .transition(.identity)
        } else {
            destinationToken(viewModel: viewModel)
                .matchedGeometryEffect(
                    id: destinationInputID,
                    in: inputTransitionNamespace,
                    properties: .frame,
                    anchor: .leading
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
                action: viewModel.wrappedValue.editDestination
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
        case .station(let station):
            let routes = station.routes.prefix(3).map(\.shortName).joined(separator: " · ")
            return routes.isEmpty ? "Station" : routes
        case .address(let address):
            return address.context.isEmpty ? "Adresse" : address.context
        }
    }

    var searchTokenSystemImage: String {
        switch self {
        case .station(let station):
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
            locationModel: locationModel
        ),
        activeJourneyModel: ActiveJourneyModel(
            locationModel: locationModel,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview)
        )
    )
}
