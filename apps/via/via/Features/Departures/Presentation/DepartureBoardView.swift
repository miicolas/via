import SwiftUI

struct DepartureBoardView: View {
    let routes: [RouteBadge]
    let board: DepartureBoard

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Prochains passages")
                        .font(.headline)

                    Spacer()

                    Label(sourceTitle, systemImage: sourceSystemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(sourceColor)
                }

                Text("Mis à jour à \(board.generatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if board.groups.isEmpty {
                DepartureEmptyStateView(source: board.source)
            } else {
                let groupsByRouteID = Dictionary(grouping: board.groups) { $0.route.id }
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    LazyVStack(spacing: 12) {
                        ForEach(routes) { route in
                            DepartureLineRow(
                                route: route,
                                groups: groupsByRouteID[route.id] ?? [],
                                source: board.source,
                                now: context.date
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sourceTitle: String {
        switch board.source {
        case .realtime: "Temps réel"
        case .theoretical: "Horaires théoriques"
        case .unavailable: "Indisponible"
        }
    }

    private var sourceSystemImage: String {
        switch board.source {
        case .realtime: "wave.3.left"
        case .theoretical: "calendar"
        case .unavailable: "exclamationmark.triangle"
        }
    }

    private var sourceColor: Color {
        switch board.source {
        case .realtime: .green
        case .theoretical: .secondary
        case .unavailable: .orange
        }
    }
}
