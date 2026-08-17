import SwiftUI

struct PlaceSuggestionsView: View {
    let search: PlaceSearchState
    let recentSearches: [RecentSearch]
    let activeField: MapPlaceField?
    let location: LocationState
    let naturalJourneyQuery: String
    let onSubmitNaturalJourney: (String) -> Void
    let onSelectResult: (SearchResult) -> Void
    let onSelectRecent: (RecentSearch) -> Void
    let onRemoveRecent: (RecentSearch) -> Void
    let onUseCurrentLocation: () -> Void
    let onRetry: () -> Void

    var body: some View {
        let content = ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if activeField == .origin, case .located = location {
                    Button(action: onUseCurrentLocation) {
                        Label("Ma position", systemImage: "location.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }

                if activeField == .origin, case .locating = location {
                    ViaLoadingStatus(label: "Localisation…")
                        .padding(.vertical, 14)
                }

                if let query = submittedNaturalJourneyQuery {
                    NaturalJourneySuggestionRow(query: query) {
                        onSubmitNaturalJourney(query)
                    }
                    .padding(.vertical, 10)

                    Divider()
                }

                if let response = search.visibleResponse {
                    if response.addressSource == .unavailable {
                        degradedSearchMessage
                    }
                    resultButtons(response.results)
                    if search.isLoading {
                        SearchLoadingSkeleton(rowCount: 2)
                    }
                } else if search.isLoading {
                    SearchLoadingSkeleton()
                } else {
                    emptyContent
                }

                if case .failed = search {
                    failedMessage
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)

        content.swipeActionsContainerIfAvailable()
    }

    private var submittedNaturalJourneyQuery: String? {
        guard activeField == .destination else { return nil }
        let query = naturalJourneyQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? nil : query
    }

    @ViewBuilder
    private var emptyContent: some View {
        switch search {
        case .idle:
            let recent = recentSearches
            if recent.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ViaAIBadge()

                    Text("Demande ton trajet à Via")
                        .font(.headline)

                    Text("Écris par exemple « Gare du Nord à 11 h », puis touche Rechercher.")
                        .font(.subheadline)
                        .foregroundStyle(Color.viaAISecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .viaAISurface()
                .padding(.vertical, 16)
            } else {
                SearchQuickDestinationsView(
                    recent: recent,
                    onSelect: onSelectRecent
                )
                Divider()

                ViaSectionHeader("Récents")
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(recent) { item in
                    recentRow(item)
                    Divider()
                }
            }
        case .empty(let source):
            ContentUnavailableView(
                "Aucun résultat",
                systemImage: "mappin.slash",
                description: Text(
                    source == .unavailable
                        ? "Les adresses sont indisponibles. Essaie le nom d’une station."
                        : "Essaie une autre station ou une autre adresse."
                )
            )
            .padding(.top, 24)
        case .failed:
            EmptyView()
        case .debouncing, .loading, .loaded:
            EmptyView()
        }
    }

    private func resultButtons(_ results: [SearchResult]) -> some View {
        ForEach(results) { result in
            Button { onSelectResult(result) } label: {
                SearchResultRow(result: result)
            }
            .buttonStyle(.plain)
            Divider()
        }
    }

    private func recentRow(_ item: RecentSearch) -> some View {
        Button { onSelectRecent(item) } label: {
            RecentSearchRow(recent: item)
        }
        .buttonStyle(.plain)
        .trailingSwipeToDelete("Effacer", systemImage: "trash") {
            onRemoveRecent(item)
        }
    }

    private var degradedSearchMessage: some View {
        Label(
            "Les adresses sont momentanément indisponibles. Les stations restent affichées.",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.footnote)
        .foregroundStyle(.orange)
        .padding(.vertical, 12)
    }

    private var failedMessage: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("La recherche n’a pas pu être actualisée.")
                    .font(.subheadline.weight(.semibold))
                Button("Réessayer", systemImage: "arrow.clockwise", action: onRetry)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }
}
