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

    var body: some View {
        EmptyStateView(
            .ai(
                systemImage: "questionmark.bubble",
                title: "Un détail manque",
                message: field.question,
            ),
        ) {
            if field.target == .time {
                timeChoices
            } else if field.candidates.isEmpty {
                Text("Aucune proposition fiable n’a été trouvée.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Modifier la demande", systemImage: "pencil", action: onModify)
                    .naturalJourneyPrimaryAction()
            } else {
                placeChoices
            }
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
        VStack(spacing: 8) {
            ForEach(field.candidates) { candidate in
                SearchResultRow(result: candidate, accessibilityHint: "Choisir ce lieu") {
                    onResolvePlace(candidate)
                }
            }
        }
    }
}
