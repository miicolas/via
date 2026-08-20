import SwiftUI

struct SearchDeparturePickerView: View {
    let viewModel: SearchViewModel
    let savedPlaces: [SavedPlace]
    let selection: SearchDepartureSelection
    let onSelect: (SearchDepartureSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedShortcut: StationPlaceShortcut?
    @State private var isManualSearchPresented = false

    init(
        viewModel: SearchViewModel,
        savedPlaces: [SavedPlace] = [],
        selection: SearchDepartureSelection = .currentLocation,
        onSelect: @escaping (SearchDepartureSelection) -> Void
    ) {
        self.viewModel = viewModel
        self.savedPlaces = savedPlaces
        self.selection = selection
        self.onSelect = onSelect
        _selectedShortcut = State(initialValue: selection.shortcut)
    }

    private var availableShortcuts: [StationPlaceShortcut] {
        [.currentLocation] + savedPlaces.compactMap { place in
            switch place.role {
            case .home: .home
            case .work: .work
            case .favorite: nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Choisissez votre point de départ")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)

                    StationPlacePicker(
                        selection: $selectedShortcut,
                        shortcuts: availableShortcuts,
                        onAddPlace: { isManualSearchPresented = true }
                    )
                    .padding(.horizontal, -20)

                    Button {
                        isManualSearchPresented = true
                    } label: {
                        Label("Choisir une station ou une adresse", systemImage: "magnifyingglass")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .background(
                                Color.secondary.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Recherche manuellement une station ou une adresse de départ")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .navigationTitle("Départ")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: selectedShortcut) { _, shortcut in
            guard let shortcut else { return }
            select(shortcut)
        }
        .sheet(isPresented: $isManualSearchPresented) {
            SearchManualDepartureView(
                searchPlaces: viewModel.searchPlaces,
                onSelect: { result in
                    onSelect(.manual(result))
                    isManualSearchPresented = false
                    dismiss()
                },
                filters: viewModel.filters,
                onSetAccessibleStationsOnly: viewModel.setAccessibleStationsOnly,
                onSetRequiresAccessibleStations: viewModel.setRequiresAccessibleStations
            )
        }
    }

    private func select(_ shortcut: StationPlaceShortcut) {
        switch shortcut {
        case .currentLocation:
            onSelect(.currentLocation)
        case .home, .work:
            guard let place = savedPlaces.first(where: { place in
                switch (shortcut, place.role) {
                case (.home, .home), (.work, .work): true
                default: false
                }
            }) else { return }
            onSelect(.saved(place))
        }
        dismiss()
    }
}

#Preview {
    let locationModel = LocationModel(adapter: InMemoryLocationAdapter())
    SearchDeparturePickerView(
        viewModel: SearchViewModel(
            repository: InMemorySearchRepository.preview,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
            locationModel: locationModel
        ),
        selection: .currentLocation,
        onSelect: { _ in }
    )
}
