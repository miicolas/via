import SwiftUI

struct SearchDeparturePickerView: View {
    let repository: any SearchRepository
    let selection: SearchDepartureSelection?
    let onSelect: (SearchDepartureSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedShortcut: StationPlaceShortcut?
    @State private var isManualSearchPresented = false

    init(
        repository: any SearchRepository,
        selection: SearchDepartureSelection?,
        onSelect: @escaping (SearchDepartureSelection) -> Void
    ) {
        self.repository = repository
        self.selection = selection
        self.onSelect = onSelect
        _selectedShortcut = State(initialValue: selection?.shortcut)
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
                        shortcuts: [.currentLocation, .home, .work],
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
            onSelect(shortcut.departureSelection)
            dismiss()
        }
        .sheet(isPresented: $isManualSearchPresented) {
            SearchManualDepartureView(repository: repository) { result in
                onSelect(.manual(result))
                isManualSearchPresented = false
                dismiss()
            }
        }
    }
}

private extension SearchDepartureSelection {
    var shortcut: StationPlaceShortcut? {
        switch self {
        case .currentLocation:
            .currentLocation
        case .saved(let shortcut):
            shortcut
        case .manual:
            nil
        }
    }
}

private extension StationPlaceShortcut {
    var departureSelection: SearchDepartureSelection {
        switch self {
        case .currentLocation:
            .currentLocation
        case .home, .work:
            .saved(self)
        }
    }
}

#Preview {
    SearchDeparturePickerView(
        repository: InMemorySearchRepository.preview,
        selection: nil,
        onSelect: { _ in }
    )
}
