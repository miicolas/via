import SwiftUI
import WidgetKit

/// One tap from the Home Screen or the Lock Screen to a saved journey.
struct FavoriteJourneyWidgetView: View {
    let entry: FavoriteJourneyEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let journey = entry.journey {
            content(for: journey)
                .widgetURL(ViaWidgetLink.favoriteJourney(id: journey.id))
        } else {
            emptyState
                .widgetURL(ViaWidgetLink.search)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            WidgetEmptyAccessoryView(
                systemImage: "star",
                title: "Aucun trajet favori",
                family: family
            )
        default:
            WidgetEmptyStateView.noFavoriteJourney
        }
    }

    @ViewBuilder
    private func content(for journey: WidgetFavoriteJourney) -> some View {
        switch family {
        case .systemMedium:
            HStack(alignment: .top, spacing: 14) {
                // The configured favourite keeps the whole tile: on a medium
                // widget the others are offered beside it, each its own link,
                // rather than replacing the one the traveller chose.
                Link(destination: ViaWidgetLink.favoriteJourney(id: journey.id)) {
                    FavoriteJourneyTileView(journey: journey)
                }
                .frame(maxWidth: .infinity)

                if !entry.others.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.others.prefix(3)) { other in
                            Link(destination: ViaWidgetLink.favoriteJourney(id: other.id)) {
                                FavoriteJourneyShortcutView(journey: other)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            FavoriteJourneyAccessoryView(journey: journey, family: family)

        default:
            FavoriteJourneyTileView(journey: journey)
        }
    }
}
