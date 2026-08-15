import SwiftUI

struct DepartureBoardView: View {
    let state: DeparturesState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        switch state {
        case .idle, .loading:
            ProgressView("Chargement des prochains passages…")
                .frame(maxWidth: .infinity, alignment: .leading)

        case .failed:
            Label("Les prochains passages sont indisponibles.", systemImage: "clock.badge.exclamationmark")
                .foregroundStyle(ViaTheme.critical)

        case .ready(let response, let stale):
            let rows = departureRows(groups: response.groups, now: now)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(sourceLabel(response.source), systemImage: sourceIcon(response.source))
                        .font(ViaFont.captionSemibold)
                        .foregroundStyle(stale ? ViaTheme.muted : ViaTheme.primary)
                    Spacer()
                    if stale {
                        Text("Dernière réponse conservée")
                            .font(ViaFont.caption2)
                            .foregroundStyle(ViaTheme.muted)
                    }
                }

                if rows.isEmpty {
                    Text("Aucun passage annoncé prochainement.")
                        .font(ViaFont.subheadline)
                        .foregroundStyle(ViaTheme.muted)
                } else {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                LineBadgeView(route: row.route)
                                Text("Ligne \(row.route.shortName)")
                                    .font(ViaFont.subheadlineSemibold)
                                    .foregroundStyle(ViaTheme.ink)
                            }

                            ForEach(row.directions) { direction in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(direction.destination)
                                        .font(ViaFont.subheadline)
                                        .foregroundStyle(ViaTheme.body)
                                    Spacer()
                                    if let wait = direction.wait {
                                        Text("\(wait.primaryMinutes) min")
                                            .font(ViaFont.headline.monospacedDigit())
                                            .foregroundStyle(ViaTheme.ink)
                                        if let followingLabel = wait.followingLabel {
                                            Text(followingLabel)
                                                .font(ViaFont.caption)
                                                .foregroundStyle(ViaTheme.muted)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 2)
                    }
                }
            }
        }
    }

    private func sourceLabel(_ source: DeparturesResponse.Source) -> String {
        switch source {
        case .realtime: "Temps réel"
        case .theoretical: "Horaires théoriques"
        case .unavailable: "Service indisponible"
        }
    }

    private func sourceIcon(_ source: DeparturesResponse.Source) -> String {
        switch source {
        case .realtime: "dot.radiowaves.left.and.right"
        case .theoretical: "calendar"
        case .unavailable: "questionmark.circle"
        }
    }
}
