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
      } else if result?.reason == .elevatorDataUnavailable {
        stateContent(.elevatorDataUnavailable, actionTitle: "Réessayer")
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
      surface: .card(cornerRadius: 24, padding: 18),
      spacing: 14
    )
  }

  private func resultsContent(_ result: JourneyResult) -> some View {
    let transit = Array(transitJourneys(in: result).prefix(4))
    let direct = directJourneys(in: result)

    return VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        Text("Choisir un itinéraire")
          .font(.title3.weight(.bold))

        Spacer()

        Text(transit.count + direct.count, format: .number)
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 9)
          .padding(.vertical, 5)
          .background(.secondary.opacity(0.1), in: Capsule())
          .accessibilityLabel("\(transit.count + direct.count) itinéraires proposés")
      }

      ForEach(transit) { journey in
        journeyCard(journey, in: result)
      }

      if !direct.isEmpty {
        if !transit.isEmpty {
          Text("Sans transports")
            .font(.headline)
            .padding(.top, 8)
        }

        ForEach(direct) { journey in
          journeyCard(journey, in: result)
        }
      }
    }
  }

  private func journeyCard(_ journey: Journey, in result: JourneyResult) -> some View {
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

  /// A journey the traveller covers on their own legs or wheels. It never
  /// competes with the transit list — it reads under its own heading below.
  private func isDirectPath(_ journey: Journey) -> Bool {
    JourneyShape.of(journey).isDirectPath
  }

  private func transitJourneys(in result: JourneyResult) -> [Journey] {
    result.journeys.filter { !isDirectPath($0) }
  }

  private func directJourneys(in result: JourneyResult) -> [Journey] {
    result.journeys.filter(isDirectPath)
  }

  @ViewBuilder
  private func noRouteContent(result: JourneyResult?) -> some View {
    if result?.reason == .noAccessibleRoute {
      stateContent(.noAccessibleRoute, actionTitle: "Réessayer")
    } else if result?.reason == .noOperationalElevatorRoute {
      stateContent(.noOperationalElevatorRoute, actionTitle: "Réessayer")
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
