import SwiftUI

struct MeetupInvitationView: View {
    let model: MeetupsModel
    let profile: ProfileModel
    let savedOrigins: [MeetupOrigin]

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var origin: MeetupOrigin?
    @State private var shareLevel: MeetupShareLevel = .progressOnly
    @State private var didChooseShareLevel = false
    @State private var showsOriginPicker = false
    @State private var acceptedTick = 0
    @State private var acceptedDestination: String?
    @State private var asksToDecline = false
    @State private var interactionTick = 0
    @State private var selectionTick = 0
    @State private var declineTick = 0

    init(model: MeetupsModel, profile: ProfileModel, savedOrigins: [MeetupOrigin]) {
        self.model = model
        self.profile = profile
        self.savedOrigins = savedOrigins
        _displayName = State(initialValue: profile.displayName)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let acceptedDestination {
                    success(acceptedDestination)
                } else {
                    content
                }
            }
                .navigationTitle("Invitation")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fermer", systemImage: "xmark", role: .close) {
                            model.dismissInvitation()
                            dismiss()
                        }
                        .labelStyle(.iconOnly)
                    }
                }
        }
        .sheet(isPresented: $showsOriginPicker) {
            MeetupPlacePickerView(model: model, stationsOnly: false) { result in
                origin = MeetupOrigin(result: result)
                interactionTick += 1
            }
        }
        .confirmationDialog(
            "Refuser cette invitation ?",
            isPresented: $asksToDecline,
            titleVisibility: .visible
        ) {
            Button("Refuser", role: .destructive) {
                Task {
                    await model.declineInvitation()
                    dismiss()
                }
            }
        } message: {
            Text("L’organisateur verra que cette place est de nouveau disponible.")
        }
        .haptic(Haptic.saved, on: acceptedTick)
        .haptic(Haptic.commit, on: interactionTick)
        .haptic(Haptic.selection, on: selectionTick)
        .haptic(Haptic.warned, on: declineTick)
    }

    @ViewBuilder
    private var content: some View {
        switch model.invitationState {
        case .idle, .loading:
            EmptyStateView(.searching("Lecture de l’invitation…"))
                .frame(maxHeight: .infinity)
        case .failed:
            EmptyStateView(.unavailable(
                title: "Invitation indisponible",
                message: "Le lien est invalide ou le service ne répond pas."
            ))
            .frame(maxHeight: .infinity)
        case .loaded(let preview):
            switch preview.status {
            case .expired:
                EmptyStateView(.meetupExpired).frame(maxHeight: .infinity)
            case .full:
                EmptyStateView(.meetupFull).frame(maxHeight: .infinity)
            case .revoked:
                EmptyStateView(.meetupRevoked).frame(maxHeight: .infinity)
            case .available:
                available(preview)
            }
        }
    }

    private func available(_ preview: MeetupInvitationPreview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Invitation de \(preview.organizerDisplayName)", systemImage: "person.crop.circle.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text(preview.destination.name)
                        .font(.largeTitle.weight(.bold))
                    Label(
                        preview.targetArrivalAt.formatted(date: .complete, time: .shortened),
                        systemImage: "clock.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    Text("Chacun garde son trajet et son niveau de partage. Via calcule le point où le groupe peut se rejoindre.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Votre prénom")
                        .font(.headline)
                    TextField("Prénom affiché", text: $displayName)
                        .textContentType(.name)
                        .textFieldStyle(.plain)
                        .padding(16)
                        .background(
                            Color(uiColor: .secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .accessibilityLabel("Prénom affiché")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Votre origine privée")
                        .font(.headline)
                    MeetupPlaceCard(
                        title: "Votre départ",
                        name: origin?.name ?? "Choisir une origine",
                        detail: origin?.context ?? "Les autres ne verront jamais cette adresse.",
                        systemImage: "location.fill",
                        onCurrentLocation: {
                            interactionTick += 1
                            Task { origin = await model.currentOrigin() }
                        }
                    ) {
                        interactionTick += 1
                        showsOriginPicker = true
                    }

                    if !savedOrigins.isEmpty {
                        Menu {
                            ForEach(savedOrigins, id: \.id) { saved in
                                Button(saved.name, systemImage: origin?.id == saved.id ? "checkmark" : "star") {
                                    guard origin?.id != saved.id else { return }
                                    origin = saved
                                    selectionTick += 1
                                }
                            }
                        } label: {
                            Label("Choisir un lieu enregistré", systemImage: "star.fill")
                        }
                        .secondaryAction()
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Partage pendant le trajet")
                        .font(.headline)
                    MeetupShareLevelPickerView(selection: $shareLevel) { _ in
                        didChooseShareLevel = true
                    }
                    if !didChooseShareLevel {
                        Label(
                            "Choisissez votre niveau de confidentialité pour continuer.",
                            systemImage: "hand.tap.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if shareLevel == .positionAndProgress, model.invitationRoute?.key == nil {
                        Label(
                            "La position précise restera suspendue jusqu’à la distribution d’une nouvelle clé de groupe.",
                            systemImage: "lock.trianglebadge.exclamationmark"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .detailCard()
                    }
                }

                Button {
                    Task {
                        guard let origin else { return }
                        if await model.acceptInvitation(
                            displayName: displayName,
                            origin: origin,
                            shareLevel: shareLevel
                        ) {
                            acceptedDestination = preview.destination.name
                            acceptedTick += 1
                        }
                    }
                } label: {
                    Label("Rejoindre le rendez-vous", systemImage: "person.2.fill")
                }
                .primaryAction()
                .disabled(
                    origin == nil
                        || !didChooseShareLevel
                        || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || model.isMutating
                )

                Button("Refuser", systemImage: "xmark.circle", role: .destructive) {
                    declineTick += 1
                    asksToDecline = true
                }
                .secondaryAction()
                .tint(.red)
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    private func success(_ destination: String) -> some View {
        VStack(spacing: 22) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 84, height: 84)
                .glassEffect(.regular.tint(.green), in: .circle)
                .accessibilityHidden(true)
            Text("Rendez-vous rejoint")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Votre trajet vers \(destination) va maintenant être intégré au plan de convergence.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Terminer", systemImage: "checkmark") { dismiss() }
                .primaryAction(tint: .green)
        }
        .padding(24)
        .frame(maxHeight: .infinity)
    }
}
