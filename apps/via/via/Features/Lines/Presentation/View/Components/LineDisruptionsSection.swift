import SwiftUI

/// What is wrong with the line, in as few rows as there are problems: the ones
/// running now, then a single folded row for the planned works — a line with
/// seven closures announced must not bury today's interruption.
struct LineDisruptionsSection: View {
    let active: [LineDisruption]
    let upcoming: [LineDisruption]

    @State private var selected: LineDisruption?
    @State private var showsUpcoming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !active.isEmpty {
                Text(active.count == 1 ? "Perturbation en cours" : "Perturbations en cours")
                    .font(.title3.weight(.bold))

                rows(active)
            }

            if !upcoming.isEmpty {
                if !active.isEmpty { Divider() }
                upcomingToggle
                if showsUpcoming { rows(upcoming) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .detailCard()
        .sheet(item: $selected) { LineDisruptionDetailView(disruption: $0) }
    }

    private func rows(_ disruptions: [LineDisruption]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(disruptions) { disruption in
                if disruption.id != disruptions.first?.id {
                    Divider().padding(.leading, 36)
                }
                LineDisruptionRow(disruption: disruption) { selected = disruption }
            }
        }
    }

    private var upcomingToggle: some View {
        LineDisclosureRow(
            glyph: .symbol("calendar", tint: .secondary),
            title: "Travaux à venir · \(upcoming.count)",
            isOpen: showsUpcoming,
            accessibilityLabel: "Travaux à venir, \(upcoming.count)",
            accessibilityValue: showsUpcoming ? "Dépliés" : "Repliés",
            action: { showsUpcoming.toggle() }
        )
    }
}

#Preview {
    let detail = PreviewLineStatusRepository.metro1Detail

    ScrollView {
        LineDisruptionsSection(
            active: detail.activeDisruptions,
            upcoming: detail.upcomingDisruptions
        )
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
