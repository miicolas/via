import SwiftUI

struct ActiveJourneyPanelView: View {
    let model: ActiveJourneyModel
    let reportViewModel: ReportViewModel
    let isLargeScreen: Bool
    @Binding var activeDetent: PresentationDetent

    @State private var isStopConfirmationPresented = false
    @State private var isAlternativesPresented = false
    @State private var isReportPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if model.isOffline {
                        statusBanner(
                            title: "Hors connexion",
                            message: "Via continue avec le trajet mémorisé. " +
                                "Les nouveaux itinéraires sont suspendus.",
                            systemImage: "wifi.slash",
                            color: .orange
                        )
                    } else if !model.hasLocationFix {
                        statusBanner(
                            title: "Progression manuelle",
                            message: "La position n’est pas disponible. Utilisez le menu pour changer d’étape.",
                            systemImage: "location.slash",
                            color: .orange
                        )
                    } else if !model.hasBackgroundLocationAuthorization {
                        statusBanner(
                            title: "Suivi limité en arrière-plan",
                            message: "Gardez Via ouverte pour des changements d’étape et recalculs plus fiables.",
                            systemImage: "location.circle",
                            color: .gray
                        )
                    }

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

                    HStack(spacing: 10) {
                        Button {
                            isReportPresented = true
                        } label: {
                            Label("Signaler", systemImage: "exclamationmark.bubble")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)

                        Button {
                            model.checkForAlternative()
                        } label: {
                            Label("Plus rapide", systemImage: "arrow.triangle.branch")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .disabled(model.recalculationState == .checking)
                        .accessibilityLabel("Rechercher l’itinéraire le plus rapide")
                    }

                    if model.recalculationState == .checking {
                        ViaLoadingStatus(label: "Recherche de l’itinéraire le plus rapide…")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .navigationTitle(model.destinationName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
        }
        .presentationDetents(detents, selection: $activeDetent)
        .presentationCornerRadius(isLargeScreen ? 45 : nil)
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled()
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
        .sheet(isPresented: $isAlternativesPresented) {
            if let alternative = model.alternative {
                ActiveJourneyAlternativesView(
                    alternative: alternative,
                    onSelect: { journey in
                        Task { await model.acceptAlternative(journey) }
                    }
                )
            }
        }
        .sheet(isPresented: $isReportPresented) {
            ReportView(
                viewModel: reportViewModel,
                onClose: { isReportPresented = false }
            )
            .presentationDetents([.large])
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                switch model.phase {
                case .scheduled(let interval):
                    Text("Départ dans \(JourneyFormatting.countdown(interval))")
                        .font(.title2.weight(.bold))
                    if let journey = model.journey {
                        Text("Première étape à \(JourneyFormatting.time(journey.departureAt))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                case .underway:
                    Text("En route")
                        .font(.title2.weight(.bold))
                    if let journey = model.journey {
                        Text("Arrivée prévue à \(JourneyFormatting.time(journey.arrivalAt))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "location.fill")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
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

    private var detents: Set<PresentationDetent> {
        isLargeScreen ? [.height(260), .fraction(0.97)] : [.height(260), .large]
    }
}
