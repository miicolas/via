import SwiftUI

struct MeetupScheduleCard: View {
    @Binding var arrival: Date
    let range: ClosedRange<Date>
    var detail = "Via remonte le temps pour calculer chaque départ."

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "clock.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.purple)
                    .frame(width: 44, height: 44)
                    .background(.purple.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Heure cible")
                        .font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            }

            Divider()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    dateControl
                    timeControl
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    dateControl
                    timeControl
                }
            }
        }
        .detailCard()
    }

    private var dateControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            DatePicker(
                "",
                selection: $arrival,
                in: effectiveRange,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Date d’arrivée cible")
        }
    }

    private var timeControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            DatePicker(
                "",
                selection: $arrival,
                in: effectiveRange,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Heure d’arrivée cible")
        }
    }

    private var effectiveRange: ClosedRange<Date> {
        min(range.lowerBound, arrival)...max(range.upperBound, arrival)
    }
}
