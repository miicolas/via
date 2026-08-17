import SwiftUI

/// Standalone place picker presented when saving home, work, or a favorite;
/// deliberately decoupled from the journey planner's search state machine.
struct SavedPlacePickerView: View {
    let role: SavedPlace.Role
    let anchor: GeoCoordinate?
    let onSelect: (SearchResult) -> Void

    @State private var viewModel: SavedPlacePickerViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        role: SavedPlace.Role,
        anchor: GeoCoordinate?,
        viewModel: SavedPlacePickerViewModel,
        onSelect: @escaping (SearchResult) -> Void
    ) {
        self.role = role
        self.anchor = anchor
        self.onSelect = onSelect
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    PlaceSearchResultsList(
                        search: viewModel.search,
                        onSelect: { result in
                            onSelect(result)
                            dismiss()
                        },
                        onRetry: { viewModel.retry() }
                    ) {
                        ContentUnavailableView(
                            "Recherche un lieu",
                            systemImage: prompt.systemImage,
                            description: Text(prompt.description)
                        )
                        .padding(.top, 24)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, prompt: "Station ou adresse")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
        .onAppear { viewModel.anchor = anchor }
    }

    private var title: String {
        switch role {
        case .home: "Ajouter Maison"
        case .work: "Ajouter Travail"
        case .favorite: "Ajouter un favori"
        }
    }

    private var prompt: (systemImage: String, description: String) {
        switch role {
        case .home:
            ("house.fill", "Ton adresse ou ta gare de départ habituelle.")
        case .work:
            ("briefcase.fill", "L’adresse ou la gare de ton lieu de travail.")
        case .favorite:
            ("star.fill", "Un lieu que tu veux retrouver en un geste.")
        }
    }
}

extension View {
    /// Shared presentation contract for the saved-place picker: hosts only
    /// bind a role, the sheet writes the selection into the account.
    func savedPlacePickerSheet(
        role: Binding<SavedPlace.Role?>,
        anchor: GeoCoordinate?,
        account: AccountModel,
        makeViewModel: @escaping () -> SavedPlacePickerViewModel
    ) -> some View {
        sheet(item: role) { selectedRole in
            SavedPlacePickerView(
                role: selectedRole,
                anchor: anchor,
                viewModel: makeViewModel(),
                onSelect: { result in
                    account.setPlace(result, role: selectedRole)
                }
            )
        }
    }
}
