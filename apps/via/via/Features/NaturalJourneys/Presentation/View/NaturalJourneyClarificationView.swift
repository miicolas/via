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
        _clarificationMeaning = State(initialValue: draft.intent.datetimeRepresents == .departure
            ? .departure
            : .arrival)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AIBadge()
            Label("Un détail manque", systemImage: "questionmark.bubble")
                .font(.title2.weight(.bold))
            Text(field.question)
                .foregroundStyle(.secondary)

            if field.target == .time {
                timeChoices
            } else if field.candidates.isEmpty {
                Text("Aucune proposition fiable n’a été trouvée.")
                    .foregroundStyle(.secondary)
                Button("Modifier la demande", action: onModify)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
            } else {
                placeChoices
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var timeChoices: some View {
        if draft.intent.timeWasExplicit {
            Button("Partir à cette heure") { onResolveTime(nil, .departure) }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            Button("Arriver à cette heure") { onResolveTime(nil, .arrival) }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        } else {
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
            Button("Continuer") {
                onResolveTime(clarificationTime, clarificationMeaning)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
    }

    private var placeChoices: some View {
        ForEach(field.candidates) { candidate in
            Button {
                onResolvePlace(candidate)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: candidate.kind == .station ? "tram.fill" : "mappin")
                        .foregroundStyle(Color.aiAccent)
                        .frame(width: 28)
                    Text(candidate.name)
                        .font(.body.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 14)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
    }
}
