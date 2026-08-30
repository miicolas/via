import SwiftUI

struct MeetupsView: View {
    let model: MeetupsModel
    let friendsModel: FriendsModel
    let isSignedIn: Bool
    let profile: ProfileModel
    let savedOrigins: [MeetupOrigin]

    @Environment(\.dismiss) private var dismiss
    @State private var showsComposer = false
    @State private var showsInvitation = false
    @State private var path: [Meetup] = []
    @State private var invitationLink: MeetupInvitationLink?
    @State private var interactionTick = 0
    @State private var createdTick = 0

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Rendez-vous")
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Fermer", systemImage: "xmark", role: .close) { dismiss() }
                            .labelStyle(.iconOnly)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Créer un rendez-vous", systemImage: "plus") {
                            interactionTick += 1
                            showsComposer = true
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Créer un rendez-vous")
                    }
                }
                .navigationDestination(for: Meetup.self) { meetup in
                    MeetupDetailView(
                        model: model,
                        friendsModel: friendsModel,
                        isSignedIn: isSignedIn,
                        initialMeetup: meetup,
                        onClose: { dismiss() }
                    )
                }
        }
        .sheet(isPresented: $showsComposer) {
            MeetupComposeView(
                model: model,
                displayName: profile.displayName,
                savedOrigins: savedOrigins,
                initialDestination: model.composeDestination
            ) { meetup in
                path = [meetup]
                createdTick += 1
            }
        }
        .sheet(isPresented: $showsInvitation) {
            MeetupInvitationView(
                model: model,
                profile: profile,
                savedOrigins: savedOrigins
            )
        }
        .sheet(item: $invitationLink) { link in
            MeetupInvitationShareView(link: link)
        }
        .task {
            await model.load()
            if model.composeDestination != nil { showsComposer = true }
        }
        .onChange(of: model.requestedMeetup?.id, initial: true) { _, _ in
            guard let meetup = model.requestedMeetup else { return }
            path = [meetup]
            model.consumeRequestedMeetup()
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
        .haptic(Haptic.commit, on: interactionTick)
        .haptic(Haptic.saved, on: createdTick)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle where model.meetups.isEmpty,
             .loading where model.meetups.isEmpty:
            SkeletonList(count: 4, label: "Chargement des rendez-vous…", row: .searchResult)
        case .failed where model.meetups.isEmpty:
            EmptyStateView(.offline(title: "Rendez-vous indisponibles")) {
                RetryButton { Task { await model.load() } }
                    .primaryAction()
            }
            .frame(maxHeight: .infinity)
        default:
            if model.meetups.isEmpty && model.pendingInvitations.isEmpty {
                EmptyStateView(.noMeetups) {
                    Button("Créer un rendez-vous", systemImage: "person.2.fill") {
                        showsComposer = true
                    }
                    .primaryAction()
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    if !model.pendingInvitations.isEmpty {
                        Section {
                            GlassEffectContainer(spacing: 12) {
                                ScrollView(.horizontal) {
                                    LazyHStack(spacing: 12) {
                                        ForEach(model.pendingInvitations) { pending in
                                            Button {
                                                interactionTick += 1
                                                Task {
                                                    await model.prepareInvitation(
                                                        token: pending.token,
                                                        key: nil
                                                    )
                                                    showsInvitation = true
                                                }
                                            } label: {
                                                MeetupPendingInvitationCard(invitation: pending)
                                            }
                                            .buttonStyle(.plain)
                                            .containerRelativeFrame(
                                                .horizontal,
                                                count: 1,
                                                span: 1,
                                                spacing: 12
                                            )
                                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                                content
                                                    .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                                    .opacity(phase.isIdentity ? 1 : 0.72)
                                            }
                                        }
                                    }
                                    .scrollTargetLayout()
                                }
                                .scrollIndicators(.hidden)
                                .scrollTargetBehavior(.viewAligned)
                                .scrollClipDisabled()
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 12, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        } header: {
                            Text("Invitations reçues")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .textCase(nil)
                        }
                    }

                    if !model.meetups.isEmpty {
                        Section {
                            ForEach(model.meetups) { meetup in
                                NavigationLink(value: meetup) {
                                    MeetupCardView(meetup: meetup)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    if meetup.isOrganizer,
                                       meetup.phase != .completed,
                                       meetup.phase != .cancelled,
                                       meetup.phase != .expired {
                                        Button {
                                            interactionTick += 1
                                            Task {
                                                await model.select(meetup)
                                                invitationLink = await model.createInvitation()
                                            }
                                        } label: {
                                            Label("Inviter", systemImage: "person.badge.plus")
                                                .labelStyle(.iconOnly)
                                        }
                                        .tint(.blue)
                                        .accessibilityLabel("Inviter à \(meetup.destination.name)")
                                    }
                                }
                            }
                        } header: {
                            Text("À venir")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .background(Color(uiColor: .systemGroupedBackground))
                .hapticRefreshable { await model.load() }
            }
        }
    }
}
