import SwiftUI

struct ReportStationPickerView: View {
    let viewModel: ReportViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SearchDestinationField(
                        text: $viewModel.stationQuery,
                        prompt: "Nom de la station",
                        accessibilityLabel: "Station",
                        clearAccessibilityLabel: "Effacer la station",
                        onClear: viewModel.clearStationQuery,
                        onSubmit: viewModel.searchStationsImmediately
                    )

                    resultsContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Choisir une station")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        viewModel.cancelPresentedSheet()
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        switch viewModel.stationSearchState {
        case .idle:
            Text("Saisissez au moins deux caractères pour rechercher une station.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .loading:
            HStack {
                Spacer()
                LoadingStatus(label: "Recherche…")
                Spacer()
            }
            .padding(.vertical, 28)

        case .loaded(let stations):
            VStack(alignment: .leading, spacing: 0) {
                ForEach(stations) { station in
                    SearchResultRow(
                        result: .station(station),
                        accessibilityHint: "Sélectionne cette station"
                    ) {
                        viewModel.selectStation(station)
                    }

                    if station.id != stations.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }

        case .empty:
            SearchEmptyStateView(message: "Essayez un autre nom de station.")

        case .failed:
            SearchEmptyStateView(
                title: "Recherche indisponible",
                message: "Vérifiez votre connexion puis réessayez.",
                actionTitle: "Réessayer",
                action: viewModel.retryStationSearch
            )
        }
    }
}
