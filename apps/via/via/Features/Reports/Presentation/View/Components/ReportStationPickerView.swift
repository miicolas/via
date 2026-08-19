import SwiftUI

struct ReportStationPickerView: View {
    let viewModel: ReportViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            List {
                switch viewModel.stationSearchState {
                case .idle:
                    ContentUnavailableView(
                        "Rechercher une station",
                        systemImage: "tram.fill",
                        description: Text("Saisissez au moins deux caractères.")
                    )
                    .listRowBackground(Color.clear)

                case .loading:
                    HStack {
                        Spacer()
                        ProgressView("Recherche…")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                case .loaded(let stations):
                    ForEach(stations) { station in
                        SearchResultRow(
                            result: .station(station),
                            accessibilityHint: "Sélectionne cette station"
                        ) {
                            viewModel.selectStation(station)
                        }
                    }

                case .empty:
                    ContentUnavailableView.search(text: viewModel.stationQuery)
                        .listRowBackground(Color.clear)

                case .failed:
                    VStack(spacing: 12) {
                        ContentUnavailableView(
                            "Recherche indisponible",
                            systemImage: "wifi.exclamationmark",
                            description: Text("Impossible de rechercher les stations pour le moment.")
                        )
                        Button("Réessayer") {
                            viewModel.retryStationSearch()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Choisir une station")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.stationQuery, prompt: "Nom de la station")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        viewModel.cancelPresentedSheet()
                        dismiss()
                    }
                }
            }
        }
    }
}
