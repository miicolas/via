import SwiftUI

/// Content of the dedicated search tab. The flow reveals destination and date
/// in order; the origin remains available from the interactive subtitle menu.
@MainActor
struct SearchView: View {
    let repository: any SearchRepository
    let onSubmit: (SearchQuery) -> Void
    let onClose: () -> Void

    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var inputTransitionNamespace
    @State private var viewModel: SearchViewModel
    @State private var isDatePickerPresented = false
    @State private var isDeparturePickerPresented = false

    init(
        repository: any SearchRepository,
        onSubmit: @escaping (SearchQuery) -> Void = { _ in },
        onClose: @escaping () -> Void = {}
    ) {
        self.repository = repository
        self.onSubmit = onSubmit
        self.onClose = onClose
        _viewModel = State(initialValue: SearchViewModel(repository: repository))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Group {
                if viewModel.step == .noResults {
                    noResultsContent(viewModel: $viewModel)
                } else {
                    searchContent(viewModel: $viewModel)
                }
            }
            .navigationTitle("Recherche")
            .navigationSubtitle(viewModel.subtitle)
            .toolbarTitleDisplayMode(.large)
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
        .sheet(isPresented: $isDatePickerPresented) {
            SearchDatePickerSheet(
                date: Binding(
                    get: { viewModel.selectedDate ?? viewModel.suggestedDate },
                    set: { viewModel.confirmDate($0) }
                ),
                isDateConfirmed: viewModel.isDateConfirmed,
                minimumDate: viewModel.suggestedDate,
                onDone: {
                    let date = viewModel.selectedDate ?? viewModel.suggestedDate
                    viewModel.confirmDate(date)
                }
            )
        }
        .sheet(isPresented: $isDeparturePickerPresented) {
            SearchDeparturePickerView(
                repository: repository,
                selection: viewModel.selectedDeparture,
                onSelect: viewModel.selectDeparture
            )
        }
    }

    private func departureMenu(viewModel: Bindable<SearchViewModel>) -> some View {
        Menu {
            SearchDepartureMenuContent(
                selection: viewModel.wrappedValue.selectedDeparture,
                onSelect: viewModel.wrappedValue.selectDeparture,
                onChooseManual: { isDeparturePickerPresented = true }
            )
        } label: {
            HStack(spacing: 4) {
                Text("Depuis ")
                    .foregroundStyle(.secondary)

                Text(viewModel.wrappedValue.selectedDeparture?.title ?? "Ma position")
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityLabel("Point de départ")
        .accessibilityValue(viewModel.wrappedValue.selectedDeparture?.title ?? "Ma position")
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
                }

                if viewModel.wrappedValue.step != .destination,
                   let destination = viewModel.wrappedValue.selectedDestination {
                    SearchResultRow(result: destination) {
                        viewModel.wrappedValue.editDestination()
                    }
                }

                if viewModel.wrappedValue.step == .ready {
                    SearchSubmitButton {
                        guard let query = viewModel.wrappedValue.submitSearch() else { return }
                        onSubmit(query)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .animation(inputAnimation, value: viewModel.wrappedValue.step)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func noResultsContent(viewModel: Bindable<SearchViewModel>) -> some View {
        VStack(spacing: 0) {
            inputStage(viewModel: viewModel)
                .padding(.top, 12)

            Spacer(minLength: 24)

            SearchNoResultsView(
                onChooseAnotherDestination: viewModel.wrappedValue.editDestination,
                onEditSearch: viewModel.wrappedValue.editSubmittedSearch
            )

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func inputStage(viewModel: Bindable<SearchViewModel>) -> some View {
        let step = viewModel.wrappedValue.step

        HStack(spacing: 8) {
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
            }

            if step != .destination {
                destinationToken(viewModel: viewModel)
                    .matchedGeometryEffect(
                        id: destinationInputID,
                        in: inputTransitionNamespace,
                        properties: .frame,
                        anchor: .leading
                    )
                    .transition(.identity)
                dateInput(viewModel: viewModel)
                    .transition(inputInsertionTransition)
            }
        }
        .animation(inputAnimation, value: step)
    }

    @ViewBuilder
    private func destinationToken(viewModel: Bindable<SearchViewModel>) -> some View {
        if let destination = viewModel.wrappedValue.selectedDestination {
            SearchInputToken(
                title: destination.name,
                accessibilityLabel: "Destination \(destination.name)",
                expands: true,
                action: viewModel.wrappedValue.editDestination
            )
        }
    }

    private func dateInput(viewModel: Bindable<SearchViewModel>) -> some View {
        SearchDateInput(
            date: viewModel.wrappedValue.selectedDate ?? viewModel.wrappedValue.suggestedDate,
            action: { isDatePickerPresented = true }
        )
    }

    private var inputAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.35, extraBounce: 0.02)
    }

    private var inputInsertionTransition: AnyTransition {
        guard !reduceMotion else { return .identity }

        return .asymmetric(
            insertion: .scale(scale: 0.001, anchor: .leading).combined(with: .opacity),
            removal: .opacity
        )
    }

    private var destinationInputID: String { "search-destination-input" }
}

#Preview("Destination") {
    SearchView(repository: InMemorySearchRepository.preview)
}
