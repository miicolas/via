import SwiftUI

struct SearchJourneyResultsView: View {
    let step: SearchViewStep
    let result: JourneyResult?
    let destinationName: String
    let departureTitle: String
    var selectedJourneyID: JourneyID? = nil
    var onSelectJourney: (Journey) -> Void = { _ in }
    let onRetry: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Itinéraires")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))

            Text("Depuis \(departureTitle)")
                .font(.body)
                .foregroundStyle(.secondary)

            Label(destinationName, systemImage: "mappin.and.ellipse")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
        }
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
                stateContent(
                    title: "Données PMR indisponibles",
                    message: "La source d’accessibilité n’est pas disponible. Modifie le filtre PMR ou réessaie plus tard.",
                    systemImage: "figure.roll",
                    actionTitle: "Réessayer"
                )
            } else {
                stateContent(
                    title: "Calcul indisponible",
                    message: "Le service d’itinéraires ne répond pas pour le moment. Vérifie ta connexion puis réessaie.",
                    systemImage: "wifi.exclamationmark",
                    actionTitle: "Réessayer"
                )
            }
        case .locationBlocked(let authorization):
            stateContent(
                title: "Position indisponible",
                message: locationMessage(for: authorization),
                systemImage: "location.slash",
                actionTitle: authorization == .notDetermined ? "Autoriser la localisation" : "Réessayer"
            )
        case .failed(let error):
            stateContent(
                title: "Impossible de calculer",
                message: error.message,
                systemImage: "exclamationmark.triangle",
                actionTitle: "Réessayer"
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
            Text("Options possibles")
                .font(.headline)

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
            }
        }
    }

    @ViewBuilder
    private func noRouteContent(result: JourneyResult?) -> some View {
        if result?.reason == .noAccessibleRoute {
            stateContent(
                title: "Aucun trajet PMR vérifié",
                message: "Aucune combinaison de gares accessibles ne respecte cette recherche. Modifie la destination ou désactive le filtre de trajet PMR.",
                systemImage: "figure.roll",
                actionTitle: "Réessayer"
            )
        } else {
            SearchNoResultsView(
                onChooseAnotherDestination: onEdit,
                onEditSearch: onEdit
            )
        }
    }

    private func stateContent(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(actionTitle, action: onRetry)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)

            Button("Modifier la recherche", action: onEdit)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .accessibilityElement(children: .contain)
    }

    private func locationMessage(for authorization: LocationAuthorization) -> String {
        switch authorization {
        case .notDetermined:
            "Autorise Via à utiliser ta position pour calculer un itinéraire depuis Ma position."
        case .denied:
            "L’accès à la position est désactivé. Autorise-le dans Réglages, puis réessaie."
        case .restricted:
            "La position n’est pas disponible sur cet appareil. Choisis une autre origine dans le menu Départ."
        case .authorized:
            "Via n’a pas réussi à obtenir ta position. Réessaie ou choisis une autre origine."
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
        destinationName: "La Défense",
        departureTitle: "Ma position",
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
        destinationName: "La Défense",
        departureTitle: "Maison",
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
        destinationName: "La Défense",
        departureTitle: "Ma position",
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
        destinationName: "La Défense",
        departureTitle: "Travail",
        onRetry: {},
        onEdit: {}
    )
    .padding()
}

#Preview("Chargement") {
    SearchJourneyResultsView(
        step: .planning,
        result: nil,
        destinationName: "La Défense",
        departureTitle: "Ma position",
        onRetry: {},
        onEdit: {}
    )
    .padding()
}

#Preview("Aucun itinéraire") {
    SearchJourneyResultsView(
        step: .noRoute,
        result: SearchJourneyPreviewData.noRoute,
        destinationName: "La Défense",
        departureTitle: "Ma position",
        onRetry: {},
        onEdit: {}
    )
    .padding()
}

#Preview("Erreur") {
    SearchJourneyResultsView(
        step: .failed(.unavailable),
        result: nil,
        destinationName: "La Défense",
        departureTitle: "Ma position",
        onRetry: {},
        onEdit: {}
    )
    .padding()
}

#Preview("Localisation bloquée") {
    SearchJourneyResultsView(
        step: .locationBlocked(.denied),
        result: nil,
        destinationName: "La Défense",
        departureTitle: "Ma position",
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
