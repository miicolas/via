import SwiftUI

struct LineDisruptionsSection: View {
    let title: String
    let disruptions: [LineDisruption]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))

            ForEach(disruptions) { disruption in
                LineDisruptionCard(disruption: disruption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
