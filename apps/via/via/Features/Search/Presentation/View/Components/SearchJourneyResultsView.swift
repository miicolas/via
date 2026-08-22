import SwiftUI

struct SearchJourneyResultsView: View {
    let step: SearchViewStep
    let result: JourneyResult?
    var selectedJourneyID: JourneyID? = nil
    var scheduledReminderJourneyID: JourneyID? = nil
    var reminderLeadTime: JourneyNotificationPreferences.DepartureLeadTime = .tenMinutes
    var isUpdatingReminder = false
    var onSelectJourney: (Journey) -> Void = { _ in }
    var onScheduleReminder: (Journey, JourneyNotificationPreferences.DepartureLeadTime) -> Void = { _, _ in }
    var onCancelReminder: () -> Void = {}
    let onRetry: () -> Void
    let onEdit: () -> Void

    var body: some View {
        content
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isPlanning: Bool {
        if case .planning = step { return true }
        return false
    }

    private var content: some View {
        SkeletonGate(isLoading: isPlanning) {
            loadingContent
        } content: {
            settledContent
        }
    }

    @ViewBuilder
    private var settledContent: some View {
        switch step {
        case .planning:
            EmptyView()
        case .results:
            if let result, !result.journeys.isEmpty {
                resultsContent(result)
            } else {
                noRouteContent(result: result)
            }
        case .noRoute:
            noRouteContent(result: result)
        case .unavailable:
            if result?.reason == .accessibilityDataUnavailable {
                stateContent(.accessibilityUnavailable, actionTitle: "Réessayer")
            } else {
                stateContent(
                    .offline(
                        title: "Calcul indisponible",
                        message: "Le service d’itinéraires ne répond pas pour le moment. Vérifie ta connexion puis réessaie.",
                    ),
                    actionTitle: "Réessayer",
                )
            }
        case .locationBlocked(let authorization):
            stateContent(
                .locationBlocked(message: locationMessage(for: authorization)),
                actionTitle: authorization == .notDetermined ? "Autoriser la localisation" : "Réessayer",
            )
        case .failed(let error):
            stateContent(
                .unavailable(title: "Impossible de calculer", message: error.message),
                actionTitle: "Réessayer",
            )
        case .destination:
            EmptyView()
        }
    }

    private var loadingContent: some View {
        SkeletonList(
            count: 3,
            label: "Recherche des itinéraires…",
            row: .journeyCard,
            surface: .card(cornerRadius: 22, padding: 18),
            spacing: 12
        )
    }

    private func resultsContent(_ result: JourneyResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if result.journeys.count == 1 {
                Text("1 itinéraire")
                    .font(.headline)
            } else {
                Text("\(result.journeys.count) itinéraires")
                    .font(.headline)
            }

            ForEach(Array(result.journeys.prefix(4))) { journey in
                Button {
                    onSelectJourney(journey)
                } label: {
                    JourneySummaryCard(
                        journey: journey,
                        source: result.source,
                        isSelected: selectedJourneyID == journey.id
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Ouvre le détail de cet itinéraire et l’affiche sur la carte")
                .contextMenu {
                    JourneyReminderContextMenu(
                        selectedLeadTime: reminderLeadTime,
                        isScheduled: scheduledReminderJourneyID == journey.id,
                        isUpdating: isUpdatingReminder,
                        onSchedule: { onScheduleReminder(journey, $0) },
                        onCancel: onCancelReminder
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func noRouteContent(result: JourneyResult?) -> some View {
        if result?.reason == .noAccessibleRoute {
            stateContent(.noAccessibleRoute, actionTitle: "Réessayer")
        } else {
            EmptyStateView(
                EmptyState(
                    systemImage: "mappin.slash",
                    title: "Aucun itinéraire trouvé",
                    message: "Vérifie ta destination ou ton point de départ. Toujours aucun résultat ?",
                ),
            ) {
                Button("Choisir une autre destination", systemImage: "plus.circle.fill", action: onEdit)
                    .primaryAction()
                Button("Modifier la recherche", systemImage: "magnifyingglass", action: onEdit)
                    .secondaryAction()
            }
        }
    }

    /// Every dead end in a journey search offers the same pair: try again, or go
    /// back and change what was asked. Only the wording of the first one moves.
    private func stateContent(_ state: EmptyState, actionTitle: String) -> some View {
        EmptyStateView(state) {
            RetryButton(label: LocalizedStringKey(actionTitle), action: onRetry)
                .primaryAction()

            Button("Modifier la recherche", systemImage: "magnifyingglass", action: onEdit)
                .secondaryAction()
        }
    }

    private func locationMessage(for authorization: LocationAuthorization) -> String {
        switch authorization {
        case .notDetermined:
            "Autorise Metyro à utiliser ta position pour calculer un itinéraire depuis Ma position."
        case .denied:
            "L’accès à la position est désactivé. Autorise-le dans Réglages, puis réessaie."
        case .restricted:
            "La position n’est pas disponible sur cet appareil. Choisis une autre origine dans le menu Départ."
        case .authorized:
            "Metyro n’a pas réussi à obtenir ta position. Réessaie ou choisis une autre origine."
        }
    }
}

private extension ViaError {
    var message: String {
        switch self {
        case .transport:
            "Vérifie ta connexion Internet puis réessaie."
        case .unavailable:
            "Le service est momentanément indisponible."
        case .rateLimited:
            "Trop de demandes ont été effectuées. Réessaie dans un instant."
        case .unauthorized:
            "Ta session n’est plus valide. Réessaie après t’être reconnecté."
        case .server(let statusCode):
            "Le serveur a rencontré une erreur (\(statusCode))."
        case .decoding, .invalidConfiguration, .invalidRequest:
            "Une erreur inattendue est survenue."
        }
    }
}

#Preview("Résultats chargés") {
    SearchJourneyResultsView(
        step: .results,
        result: .mapPreview,
        selectedJourneyID: JourneyResult.mapPreview.journeys.first?.id,
        onSelectJourney: { _ in },
        onRetry: {},
        onEdit: {}
    )
    .padding()
}

#Preview("Quatre variantes") {
    SearchJourneyResultsView(
        step: .results,
        result: .mapPreview,
        selectedJourneyID: nil,
        onSelectJourney: { _ in },
        onRetry: {},
        onEdit: {}
    )
    .padding()
}

#Preview("Perturbation") {
    SearchJourneyResultsView(
        step: .results,
        result: SearchJourneyPreviewData.disrupted,
        selectedJourneyID: nil,
        onSelectJourney: { _ in },
        onRetry: {},
        onEdit: {}
    )
    .padding()
}

#Preview("Données théoriques") {
    SearchJourneyResultsView(
        step: .results,
        result: SearchJourneyPreviewData.theoretical,
        onRetry: {},
        onEdit: {}
    )
    .padding()
}

#Preview("Chargement") {
    SearchJourneyResultsView(
        step: .planning,
        result: nil,
        onRetry: {},
        onEdit: {}
    )
    .padding()
}

#Preview("Aucun itinéraire") {
    SearchJourneyResultsView(
        step: .noRoute,
        result: SearchJourneyPreviewData.noRoute,
        onRetry: {},
        onEdit: {}
    )
    .padding()
}

#Preview("Erreur") {
    SearchJourneyResultsView(
        step: .failed(.unavailable),
        result: nil,
        onRetry: {},
        onEdit: {}
    )
    .padding()
}

#Preview("Localisation bloquée") {
    SearchJourneyResultsView(
        step: .locationBlocked(.denied),
        result: nil,
        onRetry: {},
        onEdit: {}
    )
    .padding()
}

private enum SearchJourneyPreviewData {
    static let noRoute = JourneyResult(
        status: .noRoute,
        source: .realtime,
        generatedAt: .now,
        journeys: []
    )

    static let theoretical = JourneyResult(
        status: .ready,
        source: .theoretical,
        generatedAt: .now,
        journeys: JourneyResult.mapPreview.journeys
    )

    static let disrupted: JourneyResult = {
        let base = JourneyResult.mapPreview.journeys[0]
        let disruptedJourney = Journey(
            id: base.id,
            qualifier: base.qualifier,
            durationSeconds: base.durationSeconds,
            walkingDurationSeconds: base.walkingDurationSeconds,
            transferCount: base.transferCount,
            departureAt: base.departureAt,
            arrivalAt: base.arrivalAt,
            status: .disrupted,
            warnings: ["La ligne A est perturbée"],
            sections: base.sections
        )
        return JourneyResult(
            status: .ready,
            source: .realtime,
            generatedAt: .now,
            journeys: [disruptedJourney] + Array(JourneyResult.mapPreview.journeys.dropFirst())
        )
    }()
}
