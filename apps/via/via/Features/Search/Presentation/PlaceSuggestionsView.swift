import SwiftUI

struct PlaceSuggestionsView: View {
    let search: PlaceSearchState
    let recentSearches: [RecentSearch]
    let activeField: MapPlaceField
    let location: LocationState
    let naturalJourneyQuery: String
    let onSubmitNaturalJourney: (String) -> Void
    let onSelectResult: (SearchResult) -> Void
    let onSelectRecent: (RecentSearch) -> Void
    let onRemoveRecent: (RecentSearch) -> Void
    let onUseCurrentLocation: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ScrollView {
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

                PlaceSearchResultsList(
                    search: search,
                    onSelect: onSelectResult,
                    onRetry: onRetry
                ) {
                    if recentSearches.isEmpty {
                        ViaAIOnboardingCard()
                    } else {
                        RecentSearchesSection(
                            recentSearches: recentSearches,
                            onSelect: onSelectRecent,
                            onRemove: onRemoveRecent
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

        }
        .scrollDismissesKeyboard(.interactively)
        .swipeActionsContainerIfAvailable()
    }

    private var submittedNaturalJourneyQuery: String? {
        guard activeField == .destination else { return nil }
        let query = naturalJourneyQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? nil : query
    }
}
