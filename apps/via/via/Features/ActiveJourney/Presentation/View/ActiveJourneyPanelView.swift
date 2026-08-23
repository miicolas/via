import SwiftUI

struct ActiveJourneyPanelView: View {
    let model: ActiveJourneyModel
    let departureChoicesModel: JourneyDepartureChoicesModel
    let onSelectDeparture: (JourneyDepartureChoice, String) -> Void
    let onRetryDepartures: () async -> Void

    @State private var isFinishConfirmationPresented = false
    @State private var isAlternativesPresented = false
    @State private var isLocationExplanationPresented = false
    @State private var isStarting = false
    @State private var expandedSectionIDs: Set<String> = []
    @State private var hasScrolledAway = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        statuses

                        if let alternative = model.alternative {
                            JourneyAlternativeCard(
                                alternative: alternative,
                                onAccept: { Task { await model.acceptBestAlternative() } },
                                onShowOthers: { isAlternativesPresented = true },
                                onDismiss: model.dismissAlternative
                            )
                        }

                        if let journey = model.journey {
                            // Projected once for the whole rail, not per row.
                            let progress = model.progress(at: context.date)

                            // The whole trip, not just the next step: the
                            // traveller can read ahead without losing the
                            // current one, which the header keeps pinned.
                            JourneyTimelineView(
                                journey: journey,
                                mode: progress.map { .live($0) } ?? .plan,
                                expandedSectionIDs: $expandedSectionIDs,
                                departureChoices: departureChoicesModel,
                                revisableSectionIDs: ActiveJourneyRules.revisableSectionIDs(
                                    in: journey,
                                    progress: progress,
                                    isTracking: model.isTracking,
                                    at: context.date
                                ),
                                onSelectDeparture: onSelectDeparture,
                                onRetryDepartures: { Task { await onRetryDepartures() } }
                            )
                        }

                        if model.recalculationState == .checking {
                            LoadingStatus(label: "Recherche de l’itinéraire le plus rapide…")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .onScrollPhaseChange { _, phase in
                    if phase == .interacting { hasScrolledAway = true }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    header(at: context.date)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomActions(using: scroll, at: context.date)
                }
                .onChange(of: model.progress(at: context.date)?.sectionIndex) { _, _ in
                    scrollToCurrentStep(using: scroll, at: context.date)
                }
            }
        }
        .navigationTitle(model.destinationName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { journeyToolbar }
        .confirmationDialog(
            "Terminer ce trajet ?",
            isPresented: $isFinishConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Terminer le trajet", systemImage: "flag.checkered", role: .destructive) {
                Task { await model.finishJourney() }
            }
            Button("Continuer", role: .cancel) {}
        } message: {
            Text("Le trajet sera marqué comme terminé et le suivi sera arrêté.")
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
                message: "Metyro continue avec le trajet mémorisé. Les recalculs sont suspendus.",
                systemImage: "wifi.slash",
                color: .orange
            )
        } else if model.isTracking && !model.hasLocationFix {
            statusBanner(
                title: "Position indisponible",
                message: "La position n’est pas disponible. La progression reste basée sur les horaires prévus.",
                systemImage: "location.slash",
                color: .orange
            )
        } else if model.isTracking,
                  model.expectsBackgroundTracking,
                  !model.hasBackgroundLocationAuthorization {
            statusBanner(
                title: "Suivi limité en arrière-plan",
                message: "Gardez Metyro ouverte pour des changements d’étape et recalculs plus fiables.",
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

    @ViewBuilder
    private func header(at date: Date) -> some View {
        if let journey = model.journey,
           let progress = model.progress(at: date),
           let headline = model.guidanceHeadline(at: date) {
            LiveJourneyHeaderView(
                journey: journey,
                headline: headline,
                progress: progress,
                isTracking: model.isTracking
            )
        }
    }

    @ViewBuilder
    private func bottomActions(using scroll: ScrollViewProxy, at date: Date) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            if hasScrolledAway {
                recenterButton {
                    scrollToCurrentStep(using: scroll, at: date)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(.opacity.combined(with: .scale))
            }

            if model.requiresResume || shouldOfferGo(at: date) {
                primaryAction
            }
        }
    }

    private func recenterButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "location.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
                .glassEffect(.regular, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Revenir à l’étape actuelle")
        .accessibilityHint("Fait défiler le trajet jusqu’à votre position")
    }

    private func scrollToCurrentStep(using scroll: ScrollViewProxy, at date: Date) {
        guard let journey = model.journey,
              let nodeID = JourneyTimelineView.currentNodeID(
                  in: journey,
                  progress: model.progress(at: date)
              ) else { return }
        withAnimation(.snappy) {
            scroll.scrollTo(nodeID, anchor: .center)
            hasScrolledAway = false
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
        }
        .primaryAction()
        .disabled(isStarting)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var journeyToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: model.checkForAlternative) {
                Image(systemName: alternativeSystemImage)
                    .contentTransition(
                        reduceMotion
                            ? .identity
                            : .symbolEffect(
                                .replace.magic(fallback: .offUp.byLayer),
                                options: .nonRepeating
                            )
                    )
            }
            .tint(shouldRetryRecalculation ? .orange : .primary)
            .disabled(!canCheckForAlternative)
            .accessibilityLabel(alternativeTitle)
            .accessibilityHint("Recherche l’itinéraire le plus rapide")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isFinishConfirmationPresented = true
            } label: {
                Image(systemName: "flag.checkered")
            }
            .accessibilityLabel("Terminer le trajet")
            .accessibilityHint("Marque le trajet comme terminé et arrête le suivi")
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

    private var alternativeTitle: String {
        shouldRetryRecalculation ? "Réessayer" : "Plus rapide"
    }

    private var alternativeSystemImage: String {
        shouldRetryRecalculation ? "arrow.clockwise" : "arrow.triangle.branch"
    }

    private var canCheckForAlternative: Bool {
        model.recalculationState != .checking &&
            model.hasLocationFix &&
            model.canRecalculate
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
