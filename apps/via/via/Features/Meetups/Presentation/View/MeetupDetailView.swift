import SwiftUI

struct MeetupDetailView: View {
    let model: MeetupsModel
    let friendsModel: FriendsModel
    let isSignedIn: Bool
    let initialMeetup: Meetup
    let onClose: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var invitationLink: MeetupInvitationLink?
    @State private var shareLevel: MeetupShareLevel
    @State private var asksToLeave = false
    @State private var asksToCancel = false
    @State private var participantToRemove: MeetupParticipant?
    @State private var invitationToRevoke: MeetupInvitation?
    @State private var showsEditor = false
    @State private var showsFriendPicker = false
    @State private var inviteTick = 0
    @State private var destructiveTick = 0
    @AppStorage("meetup.live-activity-enabled") private var includesLiveActivity = false

    init(
        model: MeetupsModel,
        friendsModel: FriendsModel,
        isSignedIn: Bool,
        initialMeetup: Meetup,
        onClose: @escaping () -> Void
    ) {
        self.model = model
        self.friendsModel = friendsModel
        self.isSignedIn = isSignedIn
        self.initialMeetup = initialMeetup
        self.onClose = onClose
        _shareLevel = State(initialValue: initialMeetup.currentParticipant?.shareLevel ?? .off)
    }

    private var meetup: Meetup {
        if model.live.snapshot?.meetup?.id == initialMeetup.id,
           let observed = model.live.snapshot?.meetup {
            return observed
        }
        if model.selectedMeetup?.id == initialMeetup.id, let selected = model.selectedMeetup {
            return selected
        }
        return model.live.activeMeetup?.id == initialMeetup.id
            ? model.live.activeMeetup ?? initialMeetup
            : initialMeetup
    }

    private var liveParticipants: [MeetupLiveParticipant] {
        model.live.snapshot?.participants ?? []
    }

    private var isLive: Bool { model.live.activeMeetup?.id == meetup.id }

    private var isMutable: Bool {
        switch meetup.phase {
        case .draft, .planning, .ready, .live: true
        case .completed, .cancelled, .expired: false
        }
    }

    var body: some View {
        Group {
            switch meetup.phase {
            case .cancelled:
                EmptyStateView(.meetupCancelled)
                    .frame(maxHeight: .infinity)
            case .expired:
                EmptyStateView(.meetupEventExpired)
                    .frame(maxHeight: .infinity)
            default:
                detail
            }
        }
        .navigationTitle(meetup.destination.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if meetup.isOrganizer && isMutable {
                organizerToolbar
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Fermer", systemImage: "xmark", role: .close, action: onClose)
                    .labelStyle(.iconOnly)
            }
        }
        .sheet(item: $invitationLink) { link in
            MeetupInvitationShareView(link: link)
        }
        .sheet(isPresented: $showsEditor) {
            MeetupEditView(model: model, meetup: meetup)
        }
        .sheet(isPresented: $showsFriendPicker) {
            MeetupFriendPickerView(model: friendsModel) { friend in
                Task { invitationLink = await model.createInvitation(invitedUserId: friend.id) }
            }
        }
        .confirmationDialog(
            "Quitter ce rendez-vous ?",
            isPresented: $asksToLeave,
            titleVisibility: .visible
        ) {
            Button("Quitter", role: .destructive) {
                Task { if await model.leave() { dismiss() } }
            }
        }
        .confirmationDialog(
            participantToRemove.map { "Retirer \($0.displayName) ?" } ?? "Retirer ce participant ?",
            isPresented: Binding(
                get: { participantToRemove != nil },
                set: { if !$0 { participantToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Retirer", role: .destructive) {
                guard let participant = participantToRemove else { return }
                participantToRemove = nil
                Task { await model.remove(participant) }
            }
        }
        .confirmationDialog(
            "Révoquer cette invitation ?",
            isPresented: Binding(
                get: { invitationToRevoke != nil },
                set: { if !$0 { invitationToRevoke = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Révoquer", role: .destructive) {
                guard let invitation = invitationToRevoke else { return }
                invitationToRevoke = nil
                Task { await model.revoke(invitation) }
            }
        } message: {
            Text("Le lien ou l’invitation directe ne pourra plus être accepté.")
        }
        .confirmationDialog(
            "Annuler ce rendez-vous pour tout le groupe ?",
            isPresented: $asksToCancel,
            titleVisibility: .visible
        ) {
            Button("Annuler le rendez-vous", role: .destructive) {
                Task { _ = await model.cancel() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isMutable {
                MeetupLiveActionBar(
                    isLive: isLive,
                    includesLiveActivity: includesLiveActivity,
                    isDisabled: model.isMutating,
                    onToggleLiveActivity: { includesLiveActivity.toggle() },
                    onToggleLive: {
                        Task {
                            if isLive {
                                await model.live.stop()
                            } else {
                                await model.live.start(
                                    meetup,
                                    includesLiveActivity: includesLiveActivity
                                )
                            }
                        }
                    }
                )
            }
        }
        .alert(
            "Action impossible",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) { model.clearError() }
        } message: {
            Text(model.errorMessage ?? "Réessayez dans un instant.")
        }
        .task { await model.select(initialMeetup) }
        .task(id: PollingIdentity(meetupId: meetup.id, isForeground: scenePhase == .active)) {
            guard scenePhase == .active, isMutable else { return }
            await model.live.observeWhileVisible(meetupId: meetup.id)
        }
        .onChange(of: meetup.currentParticipant?.shareLevel, initial: true) { _, level in
            guard let level, shareLevel != level else { return }
            shareLevel = level
        }
        .animation(reduceMotion ? nil : .default, value: isLive)
        .haptic(Haptic.commit, on: inviteTick)
        .haptic(Haptic.warned, on: destructiveTick)
    }

    private var detail: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                header
                MeetupMapView(
                    meetup: meetup,
                    live: liveParticipants,
                    preciseLocations: model.live.preciseLocations
                )

                section("Jonctions") {
                    MeetupTimelineView(meetup: meetup)
                        .detailCard()
                }

                section("Participants") {
                    GlassEffectContainer(spacing: 12) {
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 12) {
                                ForEach(meetup.participants) { participant in
                                    MeetupParticipantRow(
                                        participant: participant,
                                        live: liveParticipants.first { $0.participantId == participant.id },
                                        onRemove: canRemove(participant)
                                            ? {
                                                destructiveTick += 1
                                                participantToRemove = participant
                                            }
                                            : nil
                                    )
                                    .containerRelativeFrame(
                                        .horizontal,
                                        count: 1,
                                        span: 1,
                                        spacing: 12
                                    )
                                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                        content
                                            .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                            .opacity(phase.isIdentity ? 1 : 0.7)
                                    }
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollIndicators(.hidden)
                        .scrollTargetBehavior(.viewAligned)
                        .scrollClipDisabled()
                    }
                }

                if isMutable,
                   meetup.isOrganizer,
                   let invitations = meetup.invitations?.filter({ $0.status == .pending }),
                   !invitations.isEmpty {
                    section("Invitations") {
                        VStack(spacing: 14) {
                            ForEach(invitations) { invitation in
                                MeetupInvitationRow(invitation: invitation) {
                                    destructiveTick += 1
                                    invitationToRevoke = invitation
                                }
                            }
                        }
                    }
                }

                if isMutable, let current = meetup.currentParticipant {
                    section("Votre partage") {
                        MeetupShareLevelPickerView(selection: $shareLevel)
                            .onChange(of: shareLevel) { _, level in
                                guard level != meetup.currentParticipant?.shareLevel else { return }
                                Task { await model.setShareLevel(level) }
                            }
                        Text("Votre zone réelle")
                            .font(.subheadline.bold())
                        MeetupZonePickerView(selection: current.zone) { zone in
                            Task { await model.setZone(zone) }
                        }
                        .padding(16)
                        .background(
                            Color(uiColor: .secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                    }
                }

                if let warning = meetup.plan?.warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .detailCard()
                }

                if meetup.phase == .completed {
                    EmptyStateView(.meetupCompleted)
                } else {
                    managementActions
                }
            }
            .padding(20)
            .padding(.bottom, isMutable ? 18 : 0)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    @ToolbarContentBuilder
    private var organizerToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Inviter une personne", systemImage: "person.badge.plus") {
                inviteTick += 1
                Task { invitationLink = await model.createInvitation() }
            }
            .labelStyle(.iconOnly)
            .disabled(isGroupFull)
        }

        ToolbarSpacer(.fixed, placement: .topBarTrailing)

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if isSignedIn {
                    Button("Inviter un ami", systemImage: "person.2.badge.plus") {
                        inviteTick += 1
                        showsFriendPicker = true
                    }
                    .disabled(isGroupFull)
                }

                Button("Modifier", systemImage: "pencil") {
                    inviteTick += 1
                    showsEditor = true
                }
            } label: {
                Label("Plus d’actions", systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            MeetupPhaseBadgeView(
                phase: meetup.phase,
                isStale: meetup.plan?.isStale == true
            )

            Text(meetup.targetArrivalAt.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text(meetup.targetArrivalAt.formatted(date: .complete, time: .omitted))
                .font(.headline)
                .foregroundStyle(.secondary)

            Label(participantLabel, systemImage: "person.2.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if meetup.plan?.isStale == true {
                Label("Dernier plan conservé, nouveau calcul en attente", systemImage: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var managementActions: some View {
        VStack(spacing: 12) {
            if !meetup.isOrganizer {
                Button("Quitter le rendez-vous", systemImage: "rectangle.portrait.and.arrow.right") {
                    destructiveTick += 1
                    asksToLeave = true
                }
                .secondaryAction()
            }

            if meetup.isOrganizer {
                Button("Annuler pour tout le groupe", systemImage: "xmark.circle") {
                    destructiveTick += 1
                    asksToCancel = true
                }
                .secondaryAction()
                .tint(.red)
            }
        }
    }

    private var participantLabel: String {
        let count = meetup.participants.count
        return count == 1 ? "1 participant" : "\(count) participants"
    }

    private var isGroupFull: Bool {
        meetup.participants.count
            + (meetup.invitations?.filter { $0.status == .pending }.count ?? 0) >= 4
    }

    private func canRemove(_ participant: MeetupParticipant) -> Bool {
        isMutable
            && meetup.isOrganizer
            && participant.role != .organizer
            && participant.state != .left
            && participant.state != .removed
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct PollingIdentity: Hashable {
        let meetupId: String
        let isForeground: Bool
    }
}
