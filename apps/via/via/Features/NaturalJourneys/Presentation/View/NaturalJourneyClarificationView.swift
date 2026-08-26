import SwiftUI

struct NaturalJourneyClarificationView: View {
    let draft: NaturalJourneyDraft
    let field: NaturalJourneyClarification
    let onResolveTime: (Date?, JourneyDatetimeRepresents) -> Void
    let onResolvePlace: (SearchResult) -> Void
    let onModify: () -> Void

    @State private var clarificationTime: Date
    @State private var clarificationMeaning: JourneyDatetimeRepresents

    init(
        draft: NaturalJourneyDraft,
        field: NaturalJourneyClarification,
        onResolveTime: @escaping (Date?, JourneyDatetimeRepresents) -> Void,
        onResolvePlace: @escaping (SearchResult) -> Void,
        onModify: @escaping () -> Void,
    ) {
        self.draft = draft
        self.field = field
        self.onResolveTime = onResolveTime
        self.onResolvePlace = onResolvePlace
        self.onModify = onModify
        _clarificationTime = State(initialValue: draft.intent.requestedAt ?? .now)
        // Unlike the engine-facing `journeyMeaning`, an ambiguous intent defaults
        // the picker to arrival: that is the reading the parser is told to prefer.
        _clarificationMeaning = State(initialValue: draft.intent.datetimeRepresents == .departure
            ? .departure
            : .arrival)
    }

    @ViewBuilder
    var body: some View {
        if field.target != .time, field.candidates.isEmpty {
            EmptyStateView(
                .ai(
                    systemImage: "location.slash",
                    title: "Lieu introuvable",
                    message: "Aucune proposition fiable n’a été trouvée.",
                ),
            ) {
                Button("Modifier la demande", systemImage: "pencil", action: onModify)
                    .naturalJourneyPrimaryAction()
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                header

                if field.target == .time {
                    timeChoices
                } else {
                    placeChoices
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "questionmark.bubble.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.aiAccent)
                .frame(width: 40, height: 40)
                .glassEffect(.regular.tint(Color.aiSurface), in: .circle)
                .accessibilityHidden(true)

            Text(field.question)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button("Modifier la demande", systemImage: "pencil", action: onModify)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private var timeChoices: some View {
        if draft.intent.timeWasExplicit {
            Button("Partir à cette heure") { onResolveTime(nil, .departure) }
                .naturalJourneyPrimaryAction()
            Button("Arriver à cette heure") { onResolveTime(nil, .arrival) }
                .naturalJourneySecondaryAction()
        } else {
            VStack(spacing: 14) {
                DatePicker(
                    "Heure",
                    selection: $clarificationTime,
                    displayedComponents: .hourAndMinute,
                )
                .datePickerStyle(.compact)
                Picker("Contrainte horaire", selection: $clarificationMeaning) {
                    Text("Départ après").tag(JourneyDatetimeRepresents.departure)
                    Text("Arrivée avant").tag(JourneyDatetimeRepresents.arrival)
                }
                .pickerStyle(.segmented)
                .haptic(Haptic.selection, on: clarificationMeaning)
            }
            .padding(18)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))

            Button("Continuer", systemImage: "arrow.right") {
                onResolveTime(clarificationTime, clarificationMeaning)
            }
            .naturalJourneyPrimaryAction()
        }
    }

    private var placeChoices: some View {
        VStack(spacing: 0) {
            ForEach(Array(field.candidates.enumerated()), id: \.element.id) { index, candidate in
                SearchResultRow(result: candidate, accessibilityHint: "Choisir ce lieu") {
                    onResolvePlace(candidate)
                }

                if index < field.candidates.count - 1 {
                    Divider()
                        .padding(.leading, 46)
                }
            }
        }
    }
}
