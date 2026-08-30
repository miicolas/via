import SwiftUI

struct MeetupEditView: View {
    let model: MeetupsModel
    let meetup: Meetup

    @Environment(\.dismiss) private var dismiss
    @State private var destination: MeetupStation
    @State private var arrival: Date
    @State private var showsDestinationPicker = false
    @State private var interactionTick = 0
    @State private var saveTick = 0

    init(model: MeetupsModel, meetup: Meetup) {
        self.model = model
        self.meetup = meetup
        _destination = State(initialValue: meetup.destination)
        _arrival = State(initialValue: meetup.targetArrivalAt)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ajuster le point commun")
                            .font(.largeTitle.weight(.bold))
                        Text("Le groupe recevra automatiquement un nouveau plan de convergence.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Destination")
                            .font(.title3.weight(.bold))
                        MeetupPlaceCard(
                            title: "Destination commune",
                            name: destination.name,
                            detail: "Le point de repli de tout le groupe.",
                            systemImage: "flag.checkered"
                        ) {
                            interactionTick += 1
                            showsDestinationPicker = true
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Arriver avant")
                            .font(.title3.weight(.bold))
                        MeetupScheduleCard(
                            arrival: $arrival,
                            range: Date.now...Date.now.addingTimeInterval(30 * 24 * 60 * 60),
                            detail: "Le groupe recevra automatiquement un nouvel horaire de convergence."
                        )
                    }

                    Label(
                        "Chacun conserve son consentement de partage et peut toujours quitter le rendez-vous.",
                        systemImage: "hand.raised.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer", systemImage: "xmark", role: .close) { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
            .safeAreaInset(edge: .bottom) {
                GlassEffectContainer(spacing: 12) {
                    Button("Enregistrer", systemImage: "checkmark.circle.fill") {
                        saveTick += 1
                        Task {
                            if await model.update(destination: destination, arrival: arrival) {
                                dismiss()
                            }
                        }
                    }
                    .primaryAction(tint: .blue)
                    .disabled(model.isMutating)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
        .sheet(isPresented: $showsDestinationPicker) {
            MeetupPlacePickerView(model: model, stationsOnly: true) { result in
                guard case .station(let station) = result else { return }
                destination = MeetupStation(station)
                interactionTick += 1
            }
        }
        .haptic(Haptic.commit, on: interactionTick)
        .haptic(Haptic.commit, on: saveTick)
        .haptic(Haptic.failed, on: model.errorMessage != nil) { !$0 && $1 }
    }
}
