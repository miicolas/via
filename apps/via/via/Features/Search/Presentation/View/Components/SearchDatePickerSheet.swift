import SwiftUI

struct SearchDatePickerSheet: View {
    @Binding var date: Date

    let isDateConfirmed: Bool
    let minimumDate: Date
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        date: Binding<Date>,
        isDateConfirmed: Bool = true,
        minimumDate: Date = Calendar.current.startOfDay(for: .now),
        onDone: @escaping () -> Void
    ) {
        _date = date
        self.isDateConfirmed = isDateConfirmed
        self.minimumDate = minimumDate
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                SearchCalendarView(
                    date: $date,
                    selectionIsConfirmed: isDateConfirmed,
                    minimumDate: minimumDate
                )
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Ajouter un trajet")
            .navigationSubtitle("Choisissez une date de départ")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        onDone()
                        dismiss()
                    }
                    .accessibilityLabel("Fermer le choix de date")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(36)
    }
}

#Preview {
    @Previewable @State var date = Date.now

    SearchDatePickerSheet(date: $date, onDone: {})
}
