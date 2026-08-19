import SwiftUI

/// Content of the dedicated search tab. A destination result immediately
/// becomes a journey request; the map remains visible behind the sheet.
@MainActor
struct SearchView: View {
    let viewModel: SearchViewModel
    let onClose: () -> Void

    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var inputTransitionNamespace
    @State private var isDeparturePickerPresented = false

    init(
        viewModel: SearchViewModel,
        onClose: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onClose = onClose
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
                onSelect: viewModel.selectDeparture
            )
        }
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
                        onSelectJourney: viewModel.wrappedValue.selectJourney,
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
        )
    )
}
