import SwiftUI

struct NaturalJourneyDatePickerView: View {
    let initialDate: Date
    let initialMeaning: JourneyDatetimeRepresents
    let onApply: (Date, JourneyDatetimeRepresents) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var meaning: JourneyDatetimeRepresents

    init(
        initialDate: Date,
        initialMeaning: JourneyDatetimeRepresents,
        onApply: @escaping (Date, JourneyDatetimeRepresents) -> Void,
    ) {
        self.initialDate = initialDate
        self.initialMeaning = initialMeaning
        self.onApply = onApply
        _date = State(initialValue: initialDate)
        _meaning = State(initialValue: initialMeaning)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contrainte") {
                    Picker("Sens de l’heure", selection: $meaning) {
                        Text("Départ").tag(JourneyDatetimeRepresents.departure)
                        Text("Arrivée").tag(JourneyDatetimeRepresents.arrival)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Date et heure") {
                    DatePicker(
                        "Date et heure",
                        selection: $date,
                        in: Date.now...,
                        displayedComponents: [.date, .hourAndMinute],
                    )
                    .datePickerStyle(.graphical)
                }
            }
            .navigationTitle("Horaire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Appliquer") {
                        onApply(date, meaning)
                        dismiss()
                    }
                }
            }
        }
    }
}
