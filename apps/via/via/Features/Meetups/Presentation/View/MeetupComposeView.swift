import SwiftUI

struct MeetupComposeView: View {
    let model: MeetupsModel
    let displayName: String
    let savedOrigins: [MeetupOrigin]
    let initialDestination: MeetupStation?
    let onCreated: (Meetup) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var destination: MeetupStation?
    @State private var arrival: Date
    @State private var origin: MeetupOrigin?
    @State private var shareLevel: MeetupShareLevel = .progressOnly
    @State private var picker: PickerKind?
    @State private var currentLocationTick = 0
    @State private var selectionTick = 0
    @State private var presentationTick = 0
    @State private var createTick = 0

    init(
        model: MeetupsModel,
        displayName: String,
        savedOrigins: [MeetupOrigin],
        initialDestination: MeetupStation? = nil,
        onCreated: @escaping (Meetup) -> Void
    ) {
        self.model = model
        self.displayName = displayName
        self.savedOrigins = savedOrigins
        self.initialDestination = initialDestination
        self.onCreated = onCreated
        _destination = State(initialValue: initialDestination)
        _arrival = State(initialValue: Date.now.addingTimeInterval(60 * 60))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Créez le point commun")
                            .font(.largeTitle.weight(.bold))
                        Text("Chacun garde son propre trajet. Via calcule où vous pouvez vous retrouver en route.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    destinationSection
                    arrivalSection
                    originSection

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pendant le trajet")
                            .font(.title3.bold())
                        Text("Ce choix est obligatoire et reste modifiable à tout moment.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        MeetupShareLevelPickerView(selection: $shareLevel)
                    }

                    if let errorMessage = model.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            .safeAreaInset(edge: .bottom) {
                GlassEffectContainer(spacing: 12) {
                    Button {
                        createTick += 1
                        Task { await create() }
                    } label: {
                        Label("Créer le rendez-vous", systemImage: "person.2.fill")
                    }
                    .primaryAction(tint: .blue)
                    .disabled(destination == nil || origin == nil || model.isMutating)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .navigationTitle("Nouveau rendez-vous")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer", systemImage: "xmark", role: .close) { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .sheet(item: $picker) { kind in
            MeetupPlacePickerView(model: model, stationsOnly: kind == .destination) { result in
                switch kind {
                case .destination:
                    guard case .station(let station) = result else { return }
                    destination = MeetupStation(station)
                case .origin:
                    origin = MeetupOrigin(result: result)
                }
                selectionTick += 1
            }
        }
        .haptic(Haptic.commit, on: currentLocationTick)
        .haptic(Haptic.selection, on: selectionTick)
        .haptic(Haptic.commit, on: presentationTick)
        .haptic(Haptic.commit, on: createTick)
        .haptic(Haptic.failed, on: model.errorMessage != nil) { !$0 && $1 }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Station d’arrivée")
                .font(.title3.bold())
            MeetupPlaceCard(
                title: "Destination commune",
                name: destination?.name ?? "Choisir une station",
                detail: "Le point de repli où tout le monde finit par arriver.",
                systemImage: "flag.checkered"
            ) {
                presentationTick += 1
                picker = .destination
            }
        }
    }

    private var arrivalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Arriver avant")
                .font(.title3.bold())
            MeetupScheduleCard(
                arrival: $arrival,
                range: Date.now...Date.now.addingTimeInterval(30 * 24 * 60 * 60)
            )
        }
    }

    private var originSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Votre origine privée")
                .font(.title3.bold())
            Text("Les autres ne verront que votre première station et votre départ.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            MeetupPlaceCard(
                title: "Votre départ",
                name: origin?.name ?? "Choisir une origine",
                detail: origin?.context ?? "Cette adresse reste privée.",
                systemImage: "location.fill",
                onCurrentLocation: {
                    currentLocationTick += 1
                    Task { origin = await model.currentOrigin() }
                }
            ) {
                presentationTick += 1
                picker = .origin
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
    }

    private func create() async {
        guard let destination, let origin else { return }
        if let meetup = await model.create(
            destination: destination,
            arrival: arrival,
            displayName: displayName,
            origin: origin,
            shareLevel: shareLevel
        ) {
            onCreated(meetup)
            dismiss()
        }
    }

    private enum PickerKind: String, Identifiable {
        case destination, origin
        var id: String { rawValue }
    }
}
