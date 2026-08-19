import SwiftUI

struct ActiveJourneyPanelView: View {
    let model: ActiveJourneyModel
    let onOpenReport: () -> Void

    @State private var isStopConfirmationPresented = false
    @State private var isAlternativesPresented = false
    @State private var isLocationExplanationPresented = false
    @State private var isStarting = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(at: context.date)
                    statuses

                    if let alternative = model.alternative {
                        JourneyAlternativeCard(
                            alternative: alternative,
                            onAccept: { Task { await model.acceptBestAlternative() } },
                            onShowOthers: { isAlternativesPresented = true },
                            onDismiss: model.dismissAlternative
                        )
                    }

                    if let current = model.currentInstruction {
                        ActiveJourneyInstructionCard(
                            eyebrow: "Maintenant",
                            instruction: current,
                            emphasized: true
                        )
                    }

                    if let next = model.nextInstruction {
                        ActiveJourneyInstructionCard(
                            eyebrow: "Ensuite",
                            instruction: next
                        )
                    }

                    secondaryActions

                    if model.recalculationState == .checking {
                        ViaLoadingStatus(label: "Recherche de l’itinéraire le plus rapide…")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if model.requiresResume || shouldOfferGo(at: context.date) {
                    primaryAction
                }
            }
        }
        .navigationTitle(model.destinationName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { journeyMenu }
        .confirmationDialog(
            "Arrêter ce trajet ?",
            isPresented: $isStopConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Arrêter le trajet", role: .destructive) {
                Task { await model.cancelJourney() }
            }
            Button("Continuer", role: .cancel) {}
        } message: {
            Text("Le suivi et la Live Activity seront arrêtés.")
        }
        .journeyTrackingAlert(isPresented: $isLocationExplanationPresented) {
            startTracking(allowsBackgroundTracking: $0)
        }
        .navigationDestination(isPresented: $isAlternativesPresented) {
            if let alternative = model.alternative {
                ActiveJourneyAlternativesView(
                    alternative: alternative,
                    onSelect: { journey in
                        Task { await model.acceptAlternative(journey) }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var statuses: some View {
        if model.requiresResume {
            statusBanner(
                title: "Trajet en pause",
                message: "Reprenez le trajet pour relancer les mises à jour.",
                systemImage: "pause.circle.fill",
                color: .blue
            )
        }

        if model.isOffline {
            statusBanner(
                title: "Hors connexion",
                message: "Via continue avec le trajet mémorisé. Les recalculs sont suspendus.",
                systemImage: "wifi.slash",
                color: .orange
            )
        } else if model.isTracking && !model.hasLocationFix {
            statusBanner(
                title: "Progression manuelle",
                message: "La position n’est pas disponible. Utilisez le menu pour changer d’étape.",
                systemImage: "location.slash",
                color: .orange
            )
        } else if model.isTracking,
                  model.expectsBackgroundTracking,
                  !model.hasBackgroundLocationAuthorization {
            statusBanner(
                title: "Suivi limité en arrière-plan",
                message: "Gardez Via ouverte pour des changements d’étape et recalculs plus fiables.",
                systemImage: "location.circle",
                color: .gray
            )
        }

        if model.journey?.status == .disrupted {
            statusBanner(
                title: "Trajet perturbé",
                message: "Consultez les informations ci-dessous avant de poursuivre.",
                systemImage: "exclamationmark.triangle.fill",
                color: .red
            )
        } else if model.usesTheoreticalTimes {
            statusBanner(
                title: "Horaires théoriques",
                message: "Les horaires ne sont pas actualisés en temps réel.",
                systemImage: "clock.badge.questionmark",
                color: .gray
            )
        }

        if let warnings = model.journey?.warnings, !warnings.isEmpty {
            JourneyWarningBanner(warnings: warnings)
        }

        switch model.recalculationState {
        case .noRoute:
            statusBanner(
                title: "Aucun autre itinéraire",
                message: "Le trajet mémorisé reste la meilleure option disponible.",
                systemImage: "arrow.clockwise.circle",
                color: .orange
            )
        case .failed(let error):
            statusBanner(
                title: "Recherche impossible",
                message: recalculationMessage(for: error),
                systemImage: "exclamationmark.circle",
                color: .orange
            )
        case .idle, .checking, .offline:
            EmptyView()
        }
    }

    private func header(at date: Date) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                if model.requiresResume {
                    Text("Trajet mémorisé")
                        .font(.title2.weight(.bold))
                    Text("Reprenez pour continuer le suivi")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    switch model.phase(at: date) {
                    case .scheduled(let interval):
                        Text("Départ dans \(JourneyFormatting.countdown(interval))")
                            .font(.title2.weight(.bold))
                        if let journey = model.journey {
                            Text("Première étape à \(JourneyFormatting.time(journey.departureAt))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    case .underway:
                        Text(model.isTracking ? "En route" : "Prêt à partir")
                            .font(.title2.weight(.bold))
                        if let journey = model.journey {
                            Text("Arrivée prévue à \(JourneyFormatting.time(journey.arrivalAt))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: model.isTracking ? "location.fill" : "clock.fill")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
        }
    }

    private var primaryAction: some View {
        Button {
            if model.requiresResume {
                isStarting = true
                Task {
                    await model.resume()
                    isStarting = false
                }
            } else {
                isLocationExplanationPresented = true
            }
        } label: {
            HStack(spacing: 9) {
                if isStarting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
                Text(model.requiresResume ? "Reprendre" : "Go")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .disabled(isStarting)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var secondaryActions: some View {
        HStack(spacing: 10) {
            Button {
                onOpenReport()
            } label: {
                Label("Signaler", systemImage: "exclamationmark.bubble")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)

            Button {
                model.checkForAlternative()
            } label: {
                Label(
                    shouldRetryRecalculation ? "Réessayer" : "Plus rapide",
                    systemImage: "arrow.triangle.branch"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .disabled(
                model.recalculationState == .checking ||
                    !model.hasLocationFix ||
                    !model.canRecalculate
            )
            .accessibilityLabel("Rechercher l’itinéraire le plus rapide")
        }
    }

    @ToolbarContentBuilder
    private var journeyMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Étape précédente", systemImage: "backward.end") {
                    Task { await model.moveToPreviousSection() }
                }
                Button("Étape suivante", systemImage: "forward.end") {
                    Task { await model.moveToNextSection() }
                }
                Button("Terminer", systemImage: "checkered.flag") {
                    Task { await model.finishJourney() }
                }
                Divider()
                Button("Arrêter le trajet", systemImage: "xmark", role: .destructive) {
                    isStopConfirmationPresented = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Actions du trajet")
        }
    }

    private func shouldOfferGo(at date: Date) -> Bool {
        guard !model.isTracking else { return false }
        return switch model.phase(at: date) {
        case .scheduled(let interval):
            interval <= ActiveJourneyRules.imminentDepartureInterval
        case .underway:
            true
        }
    }

    private func startTracking(allowsBackgroundTracking: Bool) {
        isStarting = true
        Task {
            await model.startTracking(allowsBackgroundTracking: allowsBackgroundTracking)
            isStarting = false
        }
    }

    private var shouldRetryRecalculation: Bool {
        switch model.recalculationState {
        case .offline, .noRoute, .failed:
            true
        case .idle, .checking:
            false
        }
    }

    private func recalculationMessage(for error: ViaError) -> String {
        switch error {
        case .invalidConfiguration, .invalidRequest:
            "La recherche ne peut pas être préparée pour le moment."
        case .transport:
            "Vérifiez votre connexion avant de réessayer."
        case .decoding:
            "La réponse reçue n’a pas pu être lue."
        case .unauthorized:
            "Votre session doit être renouvelée avant de réessayer."
        case .rateLimited:
            "Trop de recherches ont été lancées. Réessayez dans un instant."
        case .unavailable, .server:
            "Le service d’itinéraires est momentanément indisponible."
        }
    }

    private func statusBanner(
        title: String,
        message: String,
        systemImage: String,
        color: Color
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage).foregroundStyle(color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
