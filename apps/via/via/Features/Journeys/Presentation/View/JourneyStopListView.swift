import SwiftUI

struct JourneyStopListView: View {
    let stops: [JourneyStop]

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(stops) { stop in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(Color.secondary.opacity(0.45))
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                        Text(stop.name)
                            .font(.subheadline)
                        Spacer(minLength: 8)
                        if let arrivalAt = stop.arrivalAt {
                            Text(JourneyFormatting.time(arrivalAt))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            Text(stops.count == 1 ? "1 arrêt" : "\(stops.count) arrêts")
                .font(.subheadline.weight(.semibold))
        }
    }
}
